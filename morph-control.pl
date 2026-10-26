#!/usr/bin/env perl

# TODO Adjust joystick CC values.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port out_port);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'usb';

my $midi_in = in_port($in_name);
say "Opened $midi_in for MIDI input.";
my $midi_out = out_port($out_name);
say "Opened $midi_out for MIDI output.";

$SIG{INT} = sub {
    say "\nStop";
    exit;
};

while (1) { # TODO use IO::Async::Loop and friends, instead
    my $msg = $midi_in->get_message_decoded;
    if ($msg && $msg->[0] eq 'note_on') {
        print ddc($msg);
        if ($msg->[2] == 85) {
            say 'Detected 85...';
            $midi_out->cc(0, 71, 127);
        }
        elsif ($msg->[2] == 86) {
            say 'Detected 86...';
            $midi_out->cc(0, 71, 0);
        }
    }
}

sub send_it ($port, $event) {
    $port->send_event($event->@*);
}
