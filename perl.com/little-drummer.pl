#!/usr/bin/env perl

# Play and clock a MIDI device, like a drum machine or sequencer.
# Examples:
#   perl little-drummer.pl 'gs wavetable' 90 # on windows
#   perl little-drummer.pl synth 90 # with fluidsynth
#   perl little-drummer.pl usb 100 -1 # multi-timbral device

use v5.36;
use Music::SimpleDrumMachine ();

my $port = shift || 'usb';
my $bpm  = shift || 90;
my $chan = shift // 9;

my $dm = Music::SimpleDrumMachine->new(
    port_name => $port,
    bpm       => $bpm,
    chan      => $chan,
    bars      => 1,
    parts     => {
        A => \&part_A,
        B => \&part_B,
    },
    next_part => 'A', # start-off with this part
    verbose   => 1,
);

sub part_A {
    say 'Part A';
    my %patterns = (
        closed => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0)],
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0)],
        snare  => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 1 1 0)],
    );
    my $next = 'B';
    return $next, \%patterns;
}

sub part_B {
    say 'Part B';
    my %patterns = (
        closed => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0)],
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0)], # change 1: 1 0 1 0 0 0 0 0 1 0 0 0 0 0 0 0
        snare  => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 1 1 1)],
        # crash => [qw(1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)], # change 2
    );
    my $next = 'A';
    return $next, \%patterns;
}
