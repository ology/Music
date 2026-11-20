#!/usr/bin/env perl

# Bi-timbral generative sequence of tonal phrases and drum beats

# Examples:
# perl interval-hop-beats.pl --verbose
# perl interval-hop-beats.pl --verbose --bpm=90 --channels=0,1 --port='se-02' --drums='T-8'
# perl interval-hop-beats.pl --v --b=90 --c=0,1 --p='se-02' --d='T-8' # <- same

use v5.40;
use Getopt::Long qw(GetOptions);      # cli processing
use IO::Async::Loop ();               # async
use IO::Async::Timer::Periodic ();    # async
use List::Util qw(uniq);              # channel cleanup
use MIDI::RtMidi::FFI::Device ();     # rt-midi
use MIDI::Util qw(dura_size TICKS);   # motif durations, ticks per quarter
use Music::Duration::Partition ();    # rhythmic phrases
use Music::Scales qw(get_scale_MIDI); # pitches
use Music::SimpleDrumMachine ();      # beats
use Music::VoiceGen ();               # voices

my %opt = (
    port     => 'nvision',    # tonal synth name fragment
    drums    => 'fluidsynth', # drum synth name fragment
    channels => '1,2',        # two or more distinct midi channels (0 .. 15)
    bpm      => 70,           # beats-per-minute
    octave   => 2,            # 0 .. 9
    pitches  => 3,            # number of octaves
    scale    => 'minor',      # scale name
    tonic    => 'C',          # scale key base note
    jumps    => '-3,-2,2,3',  # allowed interval jumps
    verbose  => 0,
);
GetOptions(\%opt,
    'port=s',
    'drums=s',
    'bpm=i',
    'channels=s',
    'octave=i',
    'scale=s',
    'tonic=s',
    'jumps=s',
    'verbose',
);

my @channels = uniq grep { /^\d+$/ && $_ <= 15 } split /\s*,\s*/, $opt{channels};
die "No valid MIDI channels (0 .. 15) given\n" unless @channels;
my @jumps = split /\s*,\s*/, $opt{jumps};

# we are in 4/4 time...
my $ppqn           = TICKS;                   # internal ticks per quarter-note = 96
my $clock_divider  = $ppqn / 24;              # MIDI clock is always 24 per quarter
my $phrase_ticks   = 4 * $ppqn;               # a phrase is a whole note = 384 ticks
my $clock_interval = 60 / $opt{bpm} / $ppqn;  # seconds per tick
my $ticks          = 0;                       # zero-based clock ticks
my $phrase_count   = 0;                       # phrases played

my %schedule; # tick => [ [ method, @args ], ... ] of MIDI messages to send

# one independent voice (pitches) and phrase (rhythm) per channel
my %voice;
for my ($i, $ch) (indexed @channels) {
    my @pool = map {
        get_scale_MIDI($opt{tonic}, $opt{octave} + $i + $_, $opt{scale})
    } 0 .. $opt{pitches} - 1;
    $voice{$ch} = Music::VoiceGen->new(
        pitches   => \@pool,
        intervals => \@jumps,
    );
}
my %phrase = map {
    $_ => Music::Duration::Partition->new(
        size => 4, # in quarter-notes
        pool => [qw(wn dhn hn dqn qn den en sn)],
    )
} @channels;

sub open_out ($name) {
    my $out = RtMidiOut->new;
    try { $out->open_port_by_name(qr/\Q$name/i) }
    catch ($e) { die "Can't open MIDI port: $name\n" }
    return $out;
}
my $midi_out = open_out($opt{port});
say "Opened '$opt{port}' for MIDI output" if $opt{verbose};

my $loop = IO::Async::Loop->new;

# the drum machine shares loop and clock
my $dm = Music::SimpleDrumMachine->new(
    port_name => $opt{drums},
    bpm       => $opt{bpm},
    ppqn      => $ppqn,
    loop      => $loop,
    autoplay  => 0,
    virtual   => 0,
    verbose   => $opt{verbose},
);

my $timer = IO::Async::Timer::Periodic->new(
    interval   => $clock_interval,
    reschedule => 'hard', # anchor to a fixed schedule, don't let tempo drift
    on_tick    => sub {
        # send MIDI clock to both devices
        if ($ticks % $clock_divider == 0) {
            $midi_out->clock;
            $dm->clock;
        }

        $dm->tick; # drums

        # a new phrase every whole note
        trigger_notes($phrase_count++) if $ticks % $phrase_ticks == 0;

        # send everything scheduled for this tick
        if (my $events = delete $schedule{$ticks}) {
            for my $event ($events->@*) {
                my ($method, @args) = $event->@*;
                $midi_out->$method(@args);
            }
        }

        $ticks++;
    },
);

# Graceful ^C:
$loop->watch_signal(INT => sub {
    say "\nStop" if $opt{verbose};
    $timer->stop;
    silence();
    $loop->stop;
});

$timer->start;
$loop->add($timer);
$loop->run;

# Schedule a phrase for every channel: the channel's partition supplies
# the rhythm and its voice supplies a pitch per duration.
sub trigger_notes ($phrase) {
    for my $ch (@channels) {
        my $motif = $phrase{$ch}->motif;
        my $tick  = $ticks;
        for my $duration (@$motif) {
            my $note   = $voice{$ch}->rand;
            my $length = int(dura_size($duration) * $ppqn + 0.5) || 1;
            push    $schedule{$tick}->@*,           [ note_on  => $ch, $note, $dm->velocity ];
            unshift $schedule{$tick + $length}->@*, [ note_off => $ch, $note, 0 ]; # offs first
            $tick += $length;
        }
        say "$phrase. Channel $ch: ", join(' ', @$motif) if $opt{verbose};
    }
}

sub silence {
    %schedule = ();
    $midi_out->panic;
    $dm->stop;
}