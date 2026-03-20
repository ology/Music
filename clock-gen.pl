#!/usr/bin/env perl
use v5.36;
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

while (1) {
    $midi_out->clock;
    sleep($interval);
}
