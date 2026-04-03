#!/usr/bin/env perl

# Clock a MIDI device, like a drum machine or sequencer.
# Example: perl clock-gen-async.pl usb 90

use v5.36;
use feature 'try';
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::RtMidi::FFI::Device ();

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120; # beats per minute

my $interval = 60 / $bpm / 24; # seconds / bpm / clocks-per-beat

# open the named midi device for output
my $midi_out = RtMidiOut->new;
try { # this will die on windows but is needed for mac
    $midi_out->open_virtual_port('RtMidiOut');
}
catch ($e) {}
$midi_out->open_port_by_name(qr/\Q$name/i);

$midi_out->start; # start the sequencer

$SIG{INT} = sub { # halt gracefully
    say "\nStop";
    try {
        $midi_out->panic; # make sure all notes are off
        $midi_out->stop; # stop the sequencer
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n";
    }
    exit;
};

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
   interval => $interval,
   on_tick  => sub { $midi_out->clock }, # send a clock tick!
);
$timer->start;

$loop->add($timer);
$loop->run;
