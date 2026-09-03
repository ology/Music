#!/usr/bin/env perl

# Ex:
# perl arping.pl # use defaults
# perl arping.pl --bpm=60 --seq_port=keyboard --clk_port=midithing --arp_type=updown --note_num=5
# perl arping.pl --b=80 --s=mate --a=converge --d=1 --o=2 --i=10 --n=11
# perl arping.pl --b=80 --s=mate --a=converge --d=3 --o=2 --i=6 --n=12
# perl arping.pl --b=80 --s=mate --a=converge --d=2 --o=2 --i=0 --n=6 --p='41,70'
# perl arping.pl --b=80 --s=mate --a=converge --d=2 --o=2 --i=0 --n='4,5,6,7'

use v5.36;
use feature 'try';
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
    seq_port => 'se-02', # sequencer MIDI device
    clk_port => 'usb',   # MIDI device (drums)
    arp_type => 'up',    # up, down, updown, converge, diverge
    note_num => '5,7',   # range of arp notes
    initial  => 1,       # within 0-based patch indices
    duration => 1,       # 0.1 .. 4 floats
    octave   => 1,       # 0 .. 9 ints
    # patches  => -1,      # -1 or CSV-string of patch numbers
    patches  => '0,2,3,12,16,18,19,21,23,27,31,37,40,41,51,57,58,64,67,70,72,75,76,80,82,83,84,86,91,92,96,97,100,102,104,105,107,108,122', # decent microKorg programs
);
GetOptions(\%opt,
    'bpm=i',
    'seq_port=s',
    'clk_port=s',
    'arp_type=s',
    'note_num=s',
    'initial=i',
    'duration=i',
    'octave=i',
    'patches=s',
);

my @note_nums = split /,/, $opt{note_num};

my @patches = $opt{patches} eq '-1' ? (0 .. 127) : split /,/, $opt{patches};

# choose the pitches to use
my @pitches = (
  get_scale_MIDI('C', $opt{octave}, 'pminor'),
  get_scale_MIDI('C', $opt{octave} + 1, 'minor'),
  get_scale_MIDI('C', $opt{octave} + 2, 'minor'),
);

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

my $device = out_port($opt{clk_port});
my $started = 0;

my $arper = Music::MelodicDevice::Arpeggiation->new(
    repeats => 1,
    verbose => 1,
);

$SIG{INT} = sub {
    say "\nStop";
    stop_device($midi_out);
    stop_device($device);
    # skip global destruction, as the cleanup has already been done
    _exit(0);
};

my $programs = Music::VoiceGen->new(
    pitches   => [0 .. $#patches], #\@patches, #[0 .. 127],
    intervals => [qw(-3 -2 -1 1 2 3)],
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

        unless ($started) { # start the clocked device, if it's not
            $device->start;
            $started++;
        }

        # fire any pending arp notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($channel, $p->{note}, velocity(-10, 10, 110));
            push @active, { note => $p->{note}, off_tick => $p->{off_tick} };
        }

        if ($ticks % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) {
                # change programs - why not?
                my $program = $opt{patches} eq '-1'
                    ? $programs->rand
                    : $patches[ $programs->rand ];
                say "\n* PC: $program";
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
    my $arped = $arper->arp(\@notes, $opt{duration}, $opt{arp_type});
    # say "N,A: @notes => ", ddc $arped;

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

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}