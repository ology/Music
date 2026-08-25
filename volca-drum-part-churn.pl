#!/usr/bin/env perl

# Play Volca Drum parts.

use v5.36;
use feature 'try';
use Array::Circular ();
use MIDI::RtMidi::FFI::Device ();
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

my $device = RtMidiOut->new;

END {
  halt($device);
}
$SIG{INT} = sub {
  halt($device);
};

try { # this will die on Windows but is needed for Mac
  $device->open_virtual_port('RtMidiOut');
}
catch ($e) {}
$device->open_port_by_name(qr/\Q$name/i);

my $program = Array::Circular->new(split /,/, $programs);

program_change($device, 0, $program->next);

try {
  $device->start;
}
catch ($e) {
  die "ERROR: $e\n";
}

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $device->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            $beat_count++;
            say '1/16th: ', $beat_count;
            if ($beat_count % $beats == 0) {
              say '1/4th: ', $beat_count;
              try {
                $device->program_change(0, $program++);
              }
              catch ($e) {
                die "ERROR: $e\n";
              }
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

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