#!/usr/bin/env perl

# Clock an external MIDI device, like a drum machine or sequencer.
# Example: perl clock-gen-async.pl usb 90

use v5.36;
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::RtMidi::FFI::Device ();
use Time::HiRes qw(sleep);

my $name = shift || 'SE-02'; # MIDI sequencer device
my $bpm  = shift || 120;

my $interval = 60 / $bpm / 24;

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('RtMidiOut');
$midi_out->open_port_by_name(qr/\Q$name/i);
$midi_out->start;

$SIG{INT} = sub { 
    say "\nStop";
    $midi_out->stop;
    exit;
};

my $loop = IO::Async::Loop->new;
my $timer = IO::Async::Timer::Periodic->new(
   interval => $interval,
   on_tick  => sub { $midi_out->clock },
);
$timer->start;
$loop->add($timer);
$loop->run;