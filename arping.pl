#!/usr/bin/env perl

# Play 2 MIDI devices with a single clock - drums and a sequencer.
# Arpeggiate (with repeats) on the 1 of each bar of a 4-bar phrase
# per sequencer program.

# Examples:
# perl arping.pl # use defaults
# perl arping.pl --verbose --initial=1 --patches='42,42' # for playing a single patch
# perl arping.pl --bpm=60 --seq_port=keyboard --clk_port=midithing --arp_type=updown \
#   --note_num=5 --initial=1 --duration=2 --octave=0 --patches=-1 --verbose
# Command-line arguments can be abbreviated to a single letter:
# perl arping.pl --v --s=mate --c=usb --a=converge --d=1 --o=2 --i=10 --n=11
# perl arping.pl --v --s=mate --a=converge --d=3 --o=2 --i=6 --n=12
# perl arping.pl --v --s=mate --a=diverge --d=2 --o=2 --i=1 --n=6 --p='41,70'
# perl arping.pl --v --n='4,5,6,7' # with varying arp note values

use v5.36;
use feature qw(try);
use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use MIDI::RtMidi::Util qw(out_port stop_device);
use MIDI::RtMidi::FFI::Device ();
use Music::MelodicDevice::Arpeggiation ();
use Music::Scales qw(get_scale_MIDI);
use Music::VoiceGen ();
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use POSIX qw(_exit); # skip global destruction
no warnings 'experimental::try';

use constant ARP_TICKS => Music::MelodicDevice::Arpeggiation::TICKS();

my %opt = (
    bpm      => 70,      # beats-per-minute
    seq_port => 'mate',  # sequencer MIDI device (microKorg)
    clk_port => 'usb',   # MIDI device (volca drums)
    arp_type => 'up',    # any combination of 'up,down,updown,converge,diverge'
    note_num => '5,7',   # range of arp notes
    repeats  => 1,       # number of arp-phrase repeats
    initial  => 1,       # within 0-based patch indices
    duration => 1,       # 0.1 .. 4 float
    octave   => '1,2,3', # octave range (0 .. 9 ints)
    jumps    => '-3,-2,-1,1,2,3', # allowed jumps to selected programs
    scale    => 'minor', # scale name as known to Music::Scales
    tonic    => 'C',     # scale key base note
    patches  => -1,      # -1=0..127 or CSV-string of patch numbers
    # patches  => '0,2,3,12,16,18,19,21,23,27,31,37,40,41,51,57,58,64,67,70,72,75,76,80,82,83,84,86,91,92,96,97,100,102,104,105,107,108,122', # decent microKorg programs
    verbose  => 0,
);
GetOptions(\%opt,
    'bpm=i',
    'seq_port=s',
    'clk_port=s',
    'arp_type=s',
    'repeats=s',
    'note_num=s',
    'initial=i',
    'duration=i',
    'octave=i',
    'patches=s',
    'jumps=s',
    'verbose',
);

my @octave    = split /,/, $opt{octave};
my @arp_types = split /,/, $opt{arp_type};
my @note_nums = split /,/, $opt{note_num};
my @jumps     = split /,/, $opt{jumps};
my @patches   = $opt{patches} eq '-1' ? (0 .. 127) : split /,/, $opt{patches};

my @pitches = map { get_scale_MIDI($opt{tonic}, $_, $opt{scale}) } @octave;

if ($opt{verbose}) {
    say "Arp types: $opt{arp_type}";
    say "Arp nums: $opt{note_num}";
    say "Arp jumps: $opt{jumps}";
    say "Arp patches: $opt{patches}";
    say "Pitches: @pitches";
}

my $channel = 0;

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $group_interval_beats = $beats / $divisions; # trigger a note group every N beats
my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start }

# open the midi devices for output
my $midi_out = out_port($opt{seq_port});
$midi_out->start;
say "Started $opt{seq_port}" if $opt{verbose};

my $device = out_port($opt{clk_port});
$device->start;
say "Started $opt{clk_port}" if $opt{verbose};

my $arper = Music::MelodicDevice::Arpeggiation->new(
    repeats => $opt{repeats},
    verbose => $opt{verbose},
);

$SIG{INT} = sub {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    stop_device($device);
    _exit(0);
};

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
        $device->clock;
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

        if (($ticks - 1) % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) {
                # change programs - why not?
                my $program = $opt{patches} eq '-1'
                    ? $programs->rand
                    : $patches[ $programs->rand ];
                say "\n* PC: $program" if $opt{verbose};
                $midi_out->program_change($channel, $program);

                # Synths need real time to load a new patch
                # before they'll reliably respond. So delay_future()
                # waits the same amount of time without blocking.
                $loop->delay_future(after => 0.1)->on_done(sub {
                    trigger_notes();
                })->retain; # keep the Future alive until it fires
            }
            elsif ($beat_count % $group_interval_beats == 0) {
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
    my @notes = sort { $a <=> $b }
        map { $pitches[int rand @pitches] } 1 .. $note_nums[int rand @note_nums]; # XXX klunky
    my $arped = $arper->arp(\@notes, $opt{duration}, $arp_types[int rand @arp_types]);

    my $on_tick = $ticks;
    for my $n (@$arped) {
        my ($dur_str, $note) = @$n;
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