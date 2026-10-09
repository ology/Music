#!/usr/bin/env perl

# Play Volca Drum parts.

use v5.36;
use feature 'try';
use Array::Circular ();
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop;
use IO::Async::Timer::Periodic;

my $bpm      = shift || 120;
my $programs = shift || '1,2,3,4';
my $name     = shift || 'USB MIDI Interface';

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $device = out_port($name);

my $program = Array::Circular->new(split /,/, $programs);

program_change($device, 0, $program->next);

try {
  $device->start;
}
catch ($e) {
  die "ERROR: $e\n";
}

my $loop = IO::Async::Loop->new;

$loop->watch_signal(INT => sub {
    say "\nStop";
    try {
        stop_device($device);
        stop_all_notes($device);
    }
    catch ($e) {
        warn "Can't halt MIDI out device '$device': $e\n";
    }
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
              program_change($device, 0, $program->next);
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

sub halt ($device) {
    say "\nStop";
    try {
        $device->panic; # make sure all notes are off
        $device->stop; # stop the sequencer
    }
    catch ($e) {
        warn "Can't halt MIDI out device '$device': $e\n";
    }
    exit;
}