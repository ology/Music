#!/usr/bin/env perl

# Use no fills and only play parts.

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
        part_A => \&part_A,
        part_B => \&part_B,
    },
    next_part => 'part_A',
    verbose   => 1,
);

sub part_A {
    say 'Part A';
    my %patterns = (
        closed => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0)],
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0)],
        snare  => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 1 1 0)],
    );
    my $next = 'part_B';
    return $next, \%patterns;
}
sub part_B {
    say 'Part B';
    my %patterns = (
        closed => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0)],
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0)],
        snare  => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 1 1 1)],
    );
    my $next = 'part_A';
    return $next, \%patterns;
}
