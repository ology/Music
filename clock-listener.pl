#!/usr/bin/env perl

# Listen for MIDI events.

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();

my $port_name = shift || 'iac';

my $device = RtMidiIn->new;
try { # this will die on Windows but is needed for Mac
    $device->open_virtual_port('RtMidiIn');
}
catch ($e) {}
$device->open_port_by_name(qr/\Q$port_name/i);
$device->ignore_timing(0);

$SIG{INT} = sub {
    say "\nStopping...";
    exit;
};

print "Listening on '$port_name'...\n";
while (1) {
    my $event = $device->get_message_decoded;
    if ($event) {
        say ddc $event;
    }
}