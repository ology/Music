#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $midi_in = RtMidiIn->new;
$midi_in->open_port_by_name(qr/tempopad/i);

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/fluid/i);

while (1) {
    my $msg = $midi_in->get_message_decoded;
    if ($msg && $msg->[0] eq 'note_on') {
        warn ddc($msg);
        if ($msg->[2] == 55) {
            $midi_out->note_on($msg->[1], 60, $msg->[3]);
        }
        elsif ($msg->[2] == 84) {
            $midi_out->note_on($msg->[1], 64, $msg->[3]);
        }
        elsif ($msg->[2] == 80) {
            $midi_out->note_on($msg->[1], 67, $msg->[3]);
        }
        elsif ($msg->[2] == 51) {
            $midi_out->note_on($msg->[1], 71, $msg->[3]);
        }
    }
}

__END__
[ 'note_on', 0, 55, 112 ]
[ 'note_on', 0, 84, 116 ]
[ 'note_on', 0, 80, 111 ]
[ 'note_on', 0, 51, 115 ]
