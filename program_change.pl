#!/usr/bin/env perl

# Play Volca Drum parts.

use v5.36;
use feature 'try';
use Array::Circular ();
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop;
use IO::Async::Timer::Periodic;

my $port    = shift || 'GP-100';
my $chan    = shift // 0;
my $program = shift // 0;
my $bank    = shift // 0;

my $device = out_port($port);

try {
    $device->control_change($chan, 0, $bank);
    $device->program_change($chan, $program);
}
catch ($e) {
    die "ERROR: $e\n";
}
