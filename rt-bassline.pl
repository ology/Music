#!/usr/bin/env perl

# Play a real-time, quasi-random walking bassline over the "Autumn Leaves"
# changes, driven by Music::Bassline::Generator, with a single MIDI clock
# that can optionally also drive a second device (e.g. a drum machine).

# Examples using fluidsynth and a generic usb interface for ports:
# perl rt-bassline.pl --verbose --y_port=synth # use defaults
# perl rt-bassline.pl --y_port=synth --x_port=drums --bpm=96 \
#   --octave=2 --patch=32 --notes_per_bar=4 --gate=0.85
# perl rt-bassline.pl --y_port=synth --modal=1 --keycenter=Bb --guitar=1

use v5.36;
use feature qw(try);
use Data::Dumper::Compact qw(ddc);               # debugging
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use List::Util qw(uniq);
use MIDI::RtController ();
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use Music::Bassline::Generator ();               # the bass!
use Music::Chord::Namer qw(chordname);           # name the chords
use Music::Chord::Note ();                       # chord names to note lists
use Music::Note ();                              # convert note types
use POSIX qw(_exit);                             # skip global destruction
use Time::HiRes qw(time);
no warnings 'experimental::try';

use constant {
    CHORD_SETTLE_SECS => 0.2, # wait this long after the last note before deciding "no more are coming"
    CHORD_WINDOW_SECS  => 1, # collect notes played within this many seconds
    CHORD_MIN_NOTES    => 3, # at least this many distinct notes = a "chord"
    CHORD_MAX_NOTES    => 4, # at most this many distinct notes = a "chord"
};

my %opt = (
    x_port        => undef,             # optional MIDI device (e.g. a drum machine, clock only)
    y_port        => undef,             # REQUIRED MIDI device (e.g. the bass synth)
    z_port        => undef,             # MIDI input device (e.g. a controller keyboard)
    bpm           => 96,                # beats-per-minute
    patch         => 32,                # GM patch: 32 = Acoustic Bass
    channel       => 0,                 # MIDI channel
    octave        => 2,                 # lowest MIDI octave for the bassline
    guitar        => 0,                 # transpose notes below E1 up an octave
    wrap          => 0,                 # ISO pitch above which notes wrap down an octave
    modal         => 0,                 # stay in one key-center instead of following each chord
    keycenter     => 'Bb',              # key-center used only when --modal is set
    chord_notes   => 1,                 # include chord tones outside of the scale
    tonic         => 0,                 # play the scale tonic on beat 1 of each bar
    intervals     => '-3,-2,-1,1,2,3',  # allowed voice-leading jumps
    notes_per_bar => 4,                 # walking-bass notes per bar (4/4 time)
    gate          => 0.85,              # note length as a fraction of its slot
    chord         => 'Cm7',             # something to play before the keys are touched
    verbose       => 0,
);
GetOptions(\%opt,
    'y_port=s',
    'x_port=s',
    'z_port=s',
    'bpm=i',
    'patch=i',
    'channel=i',
    'octave=i',
    'guitar=i',
    'wrap=s',
    'modal=i',
    'keycenter=s',
    'chord_notes=i',
    'tonic=i',
    'intervals=s',
    'notes_per_bar=i',
    'gate=f',
    'chord=s',
    'verbose',
);

die "Open MIDI port name required for 'y_port'\n" unless $opt{y_port};

my $bassline = Music::Bassline::Generator->new(
    octave      => $opt{octave},
    guitar      => $opt{guitar},
    wrap        => $opt{wrap},
    modal       => $opt{modal},
    keycenter   => $opt{keycenter},
    chord_notes => $opt{chord_notes},
    tonic       => $opt{tonic},
    intervals   => [ split /,/, $opt{intervals} ],
    verbose     => $opt{verbose},
);

if ($opt{verbose}) {
    say "BPM: $opt{bpm}";
}

my $channel = $opt{channel};

# we are in 4/4 time...
my $beats_per_bar  = 4;
my $ppqn           = 24; # MIDI clocks per quarter note
my $ticks_per_bar  = $ppqn * $beats_per_bar;
my $clock_interval = 60 / $opt{bpm} / $ppqn;

my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start, velocity => $v }

my $ticks = 0; # clock ticks

my $current_chord = $opt{chord};

my @chord_notes; # MIDI note numbers collected for the in-progress chord

my $cn = Music::Chord::Note->new;

# open the midi devices
my $midi_out = out_port($opt{y_port});
$midi_out->start;
say "Started $opt{y_port}" if $opt{verbose};
my $device;
if ($opt{x_port}) {
    $device = out_port($opt{x_port});
    $device->start;
    say "Started $opt{x_port}" if $opt{verbose};
}

$midi_out->program_change($channel, $opt{patch});

$SIG{INT} = sub {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    stop_device($device) if $opt{x_port};
    _exit(0);
};

my $loop = IO::Async::Loop->new;

my $controller;
if ($opt{z_port}) {
    $controller = MIDI::RtController->new(
        input   => $opt{z_port},
        output  => $opt{y_port},
        loop    => $loop,
        silent  => 1,
        verbose => 1,
    );
    say "Opened $opt{z_port}" if $opt{verbose};
}

$controller->add_filter(
    'chord_detect',
    ['note_on'],
    sub ($port, $dt, $event) {
        my ($ev, $chan, $note, $vel) = $event->@*;
        my $now = time();

        push @chord_notes, { note => $note, time => $now };

        # drop anything that's aged out of the trailing window
        @chord_notes = grep { $now - $_->{time} <= CHORD_WINDOW_SECS } @chord_notes;

        my @unique = uniq map { $_->{note} } @chord_notes;

        # a 4-note chord is complete the moment the 4th distinct note lands
        if (@unique >= CHORD_MAX_NOTES) {
            flush_chord([ @unique[0 .. CHORD_MAX_NOTES - 1] ]);
            @chord_notes = ();
        }

        return 0;
    }
);

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $device->clock if $opt{x_port};
        $ticks++;

        # a 3-note chord is only "done" once nothing new arrives for a bit
        if (@chord_notes) {
            my @unique     = uniq map { $_->{note} } @chord_notes;
            my ($last_time) = sort { $b <=> $a } map { $_->{time} } @chord_notes;
            if (@unique >= CHORD_MIN_NOTES && time() - $last_time > CHORD_SETTLE_SECS) {
                flush_chord(\@unique);
                @chord_notes = ();
            }
        }

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($channel, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending bassline notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($channel, $p->{note}, $p->{velocity});
            push @active, { note => $p->{note}, off_tick => $p->{off_tick} };
        }

        # every bar, generate the next bar's walking bassline
        if (($ticks - 1) % $ticks_per_bar == 0) {
            trigger_bar();
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub trigger_bar {
    my $notes;
    print "CC: $current_chord\n";
    $notes = eval { $bassline->generate($current_chord, $opt{notes_per_bar}) };
    @$notes = map { Music::Note->new($_, 'ISO')->format('midinum') } $cn->chord($opt{chord})
        unless $notes && @$notes;

    if ($opt{verbose}) {
        say "\n* Bar: $current_chord";
        print ddc $notes;
    }

    my $step_ticks = int($ticks_per_bar / $opt{notes_per_bar}) || 1;
    my $on_tick    = $ticks;

    for my $i (0 .. $#$notes) {
        push @pending, {
            note     => $notes->[$i],
            on_tick  => $on_tick,
            off_tick => $on_tick + int($step_ticks * $opt{gate}),
            velocity => velocity($i == 0 ? 100 : 80),
        };
        $on_tick += $step_ticks;
    }
}

sub velocity ($base) {
    return $base + int(rand(11)) - 5; # +/- 5 humanization
}

sub flush_chord ($notes) {
    my @sorted = sort { $a <=> $b } @$notes; # lowest pitch = the real bass; list it first
    my @names  = map { Music::Note->new($_, 'midinum')->format('isobase') } @sorted;
    my $name   = eval { chordname(@names) };
    $name =~ s/\s+//g;
    say "Chord: $name (@names)" if $opt{verbose};
    $current_chord = $name;
}