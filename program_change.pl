#!/usr/bin/env perl
use v5.36;
use feature 'try';
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);

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

__END__
The GP-100 contains 400 total patches (User 1–200 and Preset 201–400), Bank Select messages (CC# 0 MSB combined with CC# 32 LSB).
Bank Select (CC# 0 & CC# 32):
    Bank 0: Patches 1–128
    Bank 1: Patches 101–228
    Bank 2: Patches 201–328
    Bank 3: Patches 301–400