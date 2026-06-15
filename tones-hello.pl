#!/usr/bin/env perl

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $port = shift || 'MIDIThing'; # MIDI device

my $duration = 1; # second

my @notes = (32, 48, 60);

my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # this will die on windows
catch ($e) {}
try { $midi_out->open_port_by_name(qr/\Q$port/i) }
catch ($e) { die "Can't open MIDI port: $port\n" }
say "Sending MIDI to $port";

$SIG{INT} = sub { 
    say "\nStop";
    try {
        $midi_out->stop;
        $midi_out->panic;
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n";
    }
    exit;
};

while (1) {
    my $note = $notes[int rand @notes];

    $midi_out->note_on(
        0,
        $note,
        127
    );

    sleep(1);

    $midi_out->note_off(
        0,
        $note,
        0
    );

    sleep(1);
}
