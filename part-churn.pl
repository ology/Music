#!/usr/bin/env perl

# Play changing parts.

use v5.40;
use Array::Circular ();
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;

my $bpm      = shift || 100;
my $programs = shift || '1,2,3,4';
my $name     = shift || 'T-8';
my $channel  = shift // 15;

my @notes = qw(60 64 65 67 69 72);

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

my $program = Array::Circular->new(map { $_ - 1 } split /,/, $programs);

program_change($device, $channel, $program->current);

my $loop = IO::Async::Loop->new;

trigger_notes();

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
            if ($beat_count % ($beats * $divisions) == 0) {
              say '1/4th: ', $beat_count;
              program_change($device, $channel, $program->next);
              trigger_notes();
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub trigger_notes {
  for (1 .. 3) {
      my $note = $notes[int rand @notes];
      say "note_on: $note";
      $device->note_on($channel, $note, 127);

      $loop->add(IO::Async::Timer::Countdown->new(
          delay     => $clock_interval * $sixteenth,
          on_expire => sub {
              say "note_off: $note";
              $device->note_off($channel, $note);
          },
      )->start);
  }
}

sub program_change ($device, $chan, $program) {
  try {
    $device->program_change($chan, $program);
  }
  catch ($e) {
    die "ERROR: $e\n";
  }
}