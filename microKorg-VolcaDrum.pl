#!/usr/bin/env perl

# perl microKorg-VolcaDrum.pl 60

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(out_port halt);
use MIDI::RtMidi::FFI::Device ();
use Music::Scales qw(get_scale_MIDI);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use POSIX qw(_exit); # skip global destruction
no warnings 'experimental::try';

my $bpm     = shift || 70; # beats-per-minute
my $port    = shift || 'mate'; # MIDI device
my $clocked = shift || 'usb';  # MIDI device

# choose the pitches to use
my @pitches = (
  get_scale_MIDI('C', 2, 'pminor'),
  get_scale_MIDI('C', 3, 'minor'),
);

my $channel = 0;

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $note_duration_beats = 4; # how long each triggered note rings for
my $note_duration_ticks = $clocks_per_beat * $note_duration_beats;
my @active; # { note => $pitch, off_tick => $tick_when_it_should_stop }

# open the midi devices for output
my $midi_out = out_port($port);
$midi_out->start;

my $device = out_port($clocked);
$device->start;

# redefine what happens on halt
$SIG{INT} = sub {
    say "\nStop";
    halt($midi_out);
    halt($device);
    # skip global destruction, as the cleanup has already been done
    _exit(0);
};

# microKORG arp'ing patches
my @programs = qw(0 1 3 8 10 16 17 19 40 41 73 74 104 105);

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

        if ($ticks % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) {
                # change microKORG programs - why not?
                my $program = $programs[int rand @programs];
                say "PC: $program";
                $midi_out->program_change($channel, $program);

                # The microKORG needs real time to load the new patch
                # before it'll reliably respond. So delay_future()
                # waits the same amount of time without blocking.
                $loop->delay_future(after => 0.1)->on_done(sub {
                    for (1 .. 3) {
                        my $note = $pitches[int rand @pitches];
                        say "N: $note";
                        $midi_out->note_on($channel, $note, velocity(-10, 10, 110));
                        push @active, { note => $note, off_tick => $ticks + $note_duration_ticks };
                    }
                })->retain; # keep the Future alive until it fires
            }
            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}