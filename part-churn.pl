#!/usr/bin/env perl

# Play changing parts.

# Examples:
#  perl part-churn.pl 70 -42  # play 42 different patterns selected at random

use v5.40;
use Array::Circular ();
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);

my $bpm      = shift || 100;
my $programs = shift || '1,2,3,4'; # or a negative number of random choices
my $factor   = shift || 1; # 1=change on 64 beats, 2=32, 4=16, 8=8 beats...
my $name     = shift || 'T-8'; # open midi port name
my $channel  = shift // 15; # the T-8 changes patterns on channel 15

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $device = out_port($name);

try {
  $device->start;
}
catch ($e) {
  die "ERROR: $e\n";
}

if ($programs =~ /^-\d+$/) { # randomization
  $programs = -$programs;
  my @progs = (1 .. $programs);
  my @rands = map { $progs[int rand @progs] } 1 .. $#progs;
  $programs = join ',', @rands;
}
my $program = Array::Circular->new(map { $_ - 1 } split /,/, $programs);

program_change($device, $channel, $program->current);

my $loop = IO::Async::Loop->new;

$loop->watch_signal(INT => sub {
    say "\nStop";
    stop_device($device);
    stop_all_notes($device);
    $loop->stop;
});

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $device->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            $beat_count++;
            say '1/16th: ', $beat_count;
            if ($beat_count % ($beats * $divisions / $factor) == 0) {
              say '1/4th: ', $beat_count;
              program_change($device, $channel, $program->next);
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub program_change ($device, $chan, $program) {
  try {
    $device->program_change($chan, $program);
  }
  catch ($e) {
    die "ERROR: $e\n";
  }
}