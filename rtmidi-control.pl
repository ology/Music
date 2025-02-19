#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $midi_in  = RtMidiIn->new;
$midi_in->open_port_by_name(qr/tempopad/i);

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/fluid/i);

while (1) {
    my $msg = $midi_in->get_message_decoded;
    if ($msg) {
        warn ddc($msg);
        $midi_out->note_on(0x00, 0x3C, 0x7A);
        sleep 1;
        $midi_out->note_off(0x00, 0x3C);
        sleep 1;
    }
}
