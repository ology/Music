#!/usr/bin/env perl

# Play 2 MIDI devices with a single clock - drums and a sequencer.
# Arpeggiate (with repeats) on the 1 of each bar of a 4-bar phrase
# per sequencer program.

# Examples:
# perl arping.pl --y_port=synth --verbose # use defaults
# perl arping.pl --y_port=synth --x_port=drums --bpm=60 --arp_type=updown \
#   --note_num=5 --initial=1 --duration=2 --octave=0 --patches=-1 --verbose
# Command-line arguments can be abbreviated to a single letter:
# perl arping.pl --v --y=synth --x=usb  --p='42,42' # for playing a single patch
# perl arping.pl --v --y=synth --x=usb --a=converge --o=2 --i=63 --n=11
# perl arping.pl --v --y=synth --x=usb --a=converge --d=3 --o=2 --i=10 --n=12
# perl arping.pl --v --y=synth --x=usb --a=diverge --d=2 --o=2 --n=6 --p='41,70'
# perl arping.pl --v --y=synth --x=usb --n='4,5,6,7' # with varying arp note values
# perl arping.pl --v --y=synth # with no x_port MIDI device

use v5.36;
use feature qw(try);
use Data::Dumper::Compact qw(ddc);               # debugging
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use Music::MelodicDevice::Arpeggiation ();       # arpeggiation
use Music::Scales qw(get_scale_MIDI);            # pitches
use Music::VoiceGen ();                          # program change
use POSIX qw(_exit);                             # skip global destruction
no warnings 'experimental::try';

use constant ARP_TICKS => Music::MelodicDevice::Arpeggiation::TICKS();

my %opt = (
    y_port   => undef,   # REQUIRED MIDI device (e.g. microKorg)
    x_port   => undef,   # optional MIDI device (e.g. volca drum)
    bpm      => 70,      # beats-per-minute
    arp_type => 'any',   # 'any' or any known arp_type
    note_num => '5,7',   # number of arp notes
    repeats  => 1,       # number of arp-phrase repeats
    initial  => 1,       # number within the 0-based patch indices
    duration => 1,       # 0.1 .. 4 float
    octave   => '1,2,3', # octaves (0 .. 9 ints)
    scale    => 'minor', # scale name as known to Music::Scales
    tonic    => 'C',     # scale key base note
    patches  => undef,   # undef=0..127 or CSV-string of patch numbers
    # patches  => '0,2,3,12,16,18,19,21,23,27,31,37,40,41,51,57,58,64,67,70,72,75,76,80,82,83,84,86,91,92,96,97,100,102,104,105,107,108,122', # decent microKorg programs
    jumps    => '-3,-2,-1,1,2,3', # allowed jumps to selected programs
    verbose  => 0,
);
GetOptions(\%opt,
    'bpm=i',
    'y_port=s',
    'x_port=s',
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
    'verbose',
);

die "Open MIDI port name required for 'y_port'\n" unless $opt{y_port};

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
    ? sort keys $arper->arp_type->%*
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

my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start }

my $ticks      = 0; # clock ticks
my $beat_count = 0; # beats!

# synths need real time to load a new patch before they'll reliably respond
my $patch_load_secs    = 0.1;
my $ticks_per_phrase   = $beats * $clocks_per_beat;
my $lookahead_ticks    = int($patch_load_secs / $clock_interval) || 1;
my $next_phrase_tick   = 1; # tick of the next phrase's downbeat (see the -1 alignment below)
my $pc_sent_for_phrase = 0; # guard so the program change is only sent once per phrase

# open the midi devices for output
my $midi_out = out_port($opt{y_port});
$midi_out->start;
say "Started $opt{y_port}" if $opt{verbose};
my $device;
if ($opt{x_port}) {
    $device = out_port($opt{x_port});
    $device->start;
    say "Started $opt{x_port}" if $opt{verbose};
}

$SIG{INT} = sub {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    stop_device($device) if $opt{x_port};
    _exit(0);
};

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
        $device->clock if $opt{x_port};
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
$loop->run;

sub trigger_notes {
    # get a number of random pitches based on a random @note_nums value. Confused? :)
    my @notes = sort { $a <=> $b }
        map { $pitches[int rand @pitches] } 1 .. $note_nums[int rand @note_nums]; # XXX klunky

    # get an arpeggiated note list given a random arp_type
    my $arped = $arper->arp(\@notes, $opt{duration}, $arp_types[int rand @arp_types]);

    my $on_tick = $ticks;

    for my $n (@$arped) {
        my ($dur_str, $note) = @$n; # nb: a note is a duration and a pitch
        my ($dur) = $dur_str =~ /^d(\d+)$/;

        # convert from the arp's 96-ticks-per-quarter-note scale to our clock ticks
        my $step_ticks = int($dur * $clocks_per_beat / ARP_TICKS) || 1;

        push @pending, {
            note     => $note,
            on_tick  => $on_tick,
            off_tick => $on_tick + $step_ticks,
        };

        $on_tick += $step_ticks;
    }
}

sub velocity ($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}