#!/usr/bin/env perl

# Play Volca Drum parts.

use v5.36;
use feature 'try';
use Array::Circular ();
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop;
use IO::Async::Timer::Periodic;

my $name    = shift || 'GP-100';
my $program = shift // 0;
my $bank    = shift // 0;

my $device = out_port($name);

$SIG{INT} = sub {
    say "\nStop";
    try {
        stop_device($device);
        stop_all_notes($device);
    }
    catch ($e) {
        warn "Can't halt MIDI out device '$device': $e\n";
    }
    exit;
};

try {
    $device->control_change(0, 0, $bank);
    $device->program_change(0, $program);
}
catch ($e) {
    die "ERROR: $e\n";
}
