#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $midi_in = RtMidiIn->new;

$midi_in->open_port_by_name(qr/tempopad/i);

while (1) {
    my $msg = $midi_in->get_message_decoded;
    warn ddc($msg) if $msg;
}
