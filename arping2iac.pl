#!/usr/bin/env perl

# Arpeggiate the Mac IAC MIDI device.

# Examples using fluidsynth and a generic usb interface for ports:
# perl arping2iac.pl --verbose --midi_port=synth # use defaults
# perl arping2iac.pl --verbose --midi_port=synth --bpm=60 --note_num=5 \
#   --initial=1 --duration=2 --octave=0 --arp_type=updown
# Command-line arguments can be abbreviated to a single letter:
# perl arping2iac.pl --v --m=synth --a=converge --o=2 --i=63 --n=11
# perl arping2iac.pl --v --m=synth --a=converge --d=3 --o=2 --i=10 --n=12
# perl arping2iac.pl --v --m=synth --a=diverge --d=2 --o=2 --n=6 --p='41,70'
# perl arping2iac.pl --v --m=synth --a='up,down,updown' --t=G --s=major
# perl arping2iac.pl --v --m=synth --n='4,5,6,7' --spread=3
# perl arping2iac.pl --v --m=synth --p='42,42' # for playing a single patch

# While running: press 'p' to pause/resume without closing the MIDI
#ports, or 'q' to quit cleanly.

use v5.36;
use feature qw(try);
use Data::Dumper::Compact qw(ddc);               # debugging
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use List::Util qw(max sum0);                     # arp-duration scaling
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use Music::MelodicDevice::Arpeggiation ();       # arpeggiation
use Music::Scales qw(get_scale_MIDI);            # pitches
use Music::VoiceGen ();                          # program change
use POSIX qw(_exit);                             # skip global destruction
use Term::TermKey::Async qw(FORMAT_VIM);         # keyboard control
no warnings 'experimental::try';

use constant ARP_TICKS => Music::MelodicDevice::Arpeggiation::TICKS();

my %opt = (
    midi_port => 'iac',   # REQUIRED MIDI device (e.g. IAC Bus)
    bpm       => 70,      # beats-per-minute
    arp_type  => 'any',   # 'any' or any known arp_type
    note_num  => '5,7',   # number of arp notes
    repeats   => 1,       # number of arp-phrase repeats
    initial   => 1,       # number within the 0-based patch indices
    duration  => 1,       # 0.1 .. 4 float
    octave    => '1,2,3', # octaves (0 .. 9 ints)
    scale     => 'minor', # scale name as known to Music::Scales
    tonic     => 'C',     # scale key base note
    patches   => undef,   # undef=0..127 or CSV-string of patch numbers
    jumps     => '-3,-2,-1,1,2,3', # allowed jumps to selected programs
    spread    => 4,       # beats an arp should stretch across
    verbose   => 0,
);
GetOptions(\%opt,
    'bpm=i',
    'midi_port=s',
    'arp_type=s',
    'repeats=s',
    'note_num=s',
    'initial=i',
    'duration=f',
    'octave=s',
    'scale=s',
    'tonic=s',
    'patches=s',
    'jumps=s',
    'spread=i',
    'verbose',
);

die "Open MIDI port name required for 'midi_port'\n" unless $opt{midi_port};

my $arper = Music::MelodicDevice::Arpeggiation->new(
    repeats => $opt{repeats},
    verbose => $opt{verbose},
);

# split things
my @octave    = split /,/, $opt{octave};
my @note_nums = split /,/, $opt{note_num};
my @jumps     = split /,/, $opt{jumps};
my @patches   = defined $opt{patches} ? split /,/, $opt{patches} : (0 .. 127);
my @arp_types = $opt{arp_type} eq 'any'
    ? keys $arper->arp_type->%*
    : split /,/, $opt{arp_type};

# get range of pitches by octave
my @pitches = map { get_scale_MIDI($opt{tonic}, $_, $opt{scale}) } @octave;

if ($opt{verbose}) {
    say "Arp types: $opt{arp_type}";
    say "Arp nums: $opt{note_num}";
    say "Arp jumps: $opt{jumps}";
    say "Arp patches: $opt{patches}" if $opt{patches};
    say "Pitches: @pitches";
}

my $channel = 0; # this code talks to a single channel

# we are in 4/4 time...
my $divisions       = 4; # divisions of a quarter-note into 16ths
my $beats           = $divisions * $divisions; # beats in a phrase
my $clocks_per_beat = 6 * $divisions; # PPQN
my $clock_interval  = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn

$opt{spread} //= $divisions; # default: stretch each arp across one full bar

my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start }
my $paused = 0; # toggled by the 'p' key, without tearing down the MIDI ports

my $ticks      = 0; # clock ticks
my $beat_count = 0; # beats!

# synths need real time to load a new patch before they'll reliably respond
my $patch_load_secs    = 0.1;
my $ticks_per_phrase   = $beats * $clocks_per_beat;
my $lookahead_ticks    = int($patch_load_secs / $clock_interval) || 1;
my $next_phrase_tick   = 1; # tick of the next phrase's downbeat (see the -1 alignment below)
my $pc_sent_for_phrase = 0; # guard so the program change is only sent once per phrase

# open the midi device for output
my $midi_out = out_port($opt{midi_port});
$midi_out->start;
say "Started $opt{midi_port}" if $opt{verbose};

$SIG{INT} = \&shutdown_and_exit;

# synth programs are indexes into the patches list
my $programs = Music::VoiceGen->new(
    pitches   => [0 .. $#patches], #\@patches, #[0 .. 127],
    intervals => \@jumps,
);
$programs->context($opt{initial});

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($channel, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending arp notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($channel, $p->{note}, velocity(-10, 10, 110));
            push @active, { note => $p->{note}, off_tick => $p->{off_tick} };
        }

        # pre-load the next phrase's synth patch a little early, so it's
        # ready by the time the new phrase's downbeat actually arrives
        if (!$pc_sent_for_phrase && $ticks >= $next_phrase_tick - $lookahead_ticks) {
            my $program = $patches[ $programs->rand ];
            say "\n* PC: $program" if $opt{verbose};
            $midi_out->program_change($channel, $program);
            $pc_sent_for_phrase = 1;
        }

        # TODO explain this modulo
        if (($ticks - 1) % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) { # every 16th beat...
                trigger_notes();
                $next_phrase_tick += $ticks_per_phrase; # schedule the next phrase's pre-load point
                $pc_sent_for_phrase = 0; # reset the guard for the next phrase
            }
            elsif ($beat_count % $divisions == 0) { # every div=4 beats
                trigger_notes();
            }
            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $keystr = $self->format_key($key, FORMAT_VIM);

        if ($keystr eq 'p') {
            toggle_pause();
        }
        elsif ($keystr eq 'q' || $keystr eq 'C-c') {
            shutdown_and_exit();
        }
    },
);
$loop->add($tka);

say "Press 'p' to pause/resume, 'q' to quit" if $opt{verbose};

$loop->run;

sub trigger_notes {
    # get a number of random pitches based on a random @note_nums value. Confused? :)
    my @notes = sort { $a <=> $b }
        map { $pitches[int rand @pitches] } 1 .. $note_nums[int rand @note_nums]; # XXX klunky

    # get an arpeggiated note list given a random arp_type
    my $arped = $arper->arp(\@notes, $opt{duration}, $arp_types[int rand @arp_types]);

    # convert from the arp's 96-ticks-per-quarter-note scale to our clock ticks
    my @raw_ticks = map {
        my ($dur) = $_->[0] =~ /^d(\d+)$/;
        max(1, int($dur * $clocks_per_beat / ARP_TICKS));
    } @$arped;

    # instead of firing the whole arp back-to-back starting at the downbeat
    # (a "one-shot"), stretch or squeeze it so it spans $opt{spread} beats.
    my $scale = 1;
    if ($opt{spread}) {
        my $raw_total = sum0(@raw_ticks) || 1;
        my $available = $opt{spread} * $clocks_per_beat;
        $scale = $available / $raw_total;
    }

    my $on_tick = $ticks;

    for my $i (0 .. $#$arped) {
        my (undef, $note) = @{ $arped->[$i] }; # nb: a note is a duration and a pitch
        my $step_ticks = max(1, int($raw_ticks[$i] * $scale));

        push @pending, {
            note     => $note,
            on_tick  => $on_tick,
            off_tick => $on_tick + $step_ticks,
        };

        $on_tick += $step_ticks;
    }
}

sub toggle_pause {
    $paused = !$paused;

    if ($paused) {
        $timer->stop; # clock ticks (and therefore note on/off scheduling) freeze here

        # silence anything currently sounding so nothing gets stuck on
        for my $n (@active) {
            $midi_out->note_off($channel, $n->{note}, 0);
        }
        @active = ();

        say "\n-- Paused --" if $opt{verbose};
    }
    else {
        $timer->start; # resumes from the same $ticks count, ports stay open throughout
        say "-- Resumed --" if $opt{verbose};
    }
}

sub velocity ($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

sub shutdown_and_exit {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    exit(0);
}