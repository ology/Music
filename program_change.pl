#!/usr/bin/env perl
use v5.36;
use feature 'try';
use MIDI::RtMidi::Util qw(out_port program_changer);

my $port     = shift || 'GP-100';
my $channel  = shift // 0;
my $program  = shift // 0;
my $msb_bank = shift // 0;
my $lsb_bank = shift // undef;

my $device = out_port($port);

$device->program_changer($program, $channel, $msb_bank, $lsb_bank);

__END__
The GP-100 contains 400 patches (User 1–200 & Preset 201–400), Bank Select messages (CC# 0 MSB combined with CC# 32 LSB).
Bank Select (CC# 0 & CC# 32):
    Bank 0: Patches 1–128
    Bank 1: Patches 101–228
    Bank 2: Patches 201–328
    Bank 3: Patches 301–400