#!/usr/bin/env perl

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $tone = shift || 'MIDIThing'; # MIDI drums
my $bpm  = shift || 70; # beats-per-minute
my $chan = shift // -1; # 0-15, 9=percussion, -1=multi-timbral

my @notes = (32, 48, 60);

my $midi_out = RtMidiOut->new;
try { # this will die on windows
    $midi_out->open_virtual_port('RtMidiOut');
}
catch ($e) {}
try {
    $midi_out->open_port_by_name(qr/\Q$tone/i);
}
catch ($e) {
    die "Can't open MIDI port: $tone";
}
say "Sending MIDI to $tone";

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
