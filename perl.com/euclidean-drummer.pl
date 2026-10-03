#!/usr/bin/env perl

# Play and clock a MIDI device, like a drum machine or sequencer.
# Examples:
#   perl euclidean-drummer.pl 'gs wavetable' 90 # on windows
#   perl euclidean-drummer.pl fluid 90 # with fluidsynth
#   perl euclidean-drummer.pl usb 100 -1 # multi-timbral device

use v5.36;
use Music::CreatingRhythms (); # for euclidean beats
use Music::SimpleDrumMachine ();

my $port = shift || 'usb';
my $bpm  = shift || 90;
my $chan = shift // 9;

my $beats  = 16;
my %primes = ( # for computing patterns
    all  => [qw(2 3 5 7 11 13)],
    to_5 => [qw(2 3 5)],
    to_7 => [qw(2 3 5 7)],
);

my $mcr = Music::CreatingRhythms->new;

my $dm = Music::SimpleDrumMachine->new(
    port_name => $port,
    bpm       => $bpm,
    chan      => $chan,
    bars      => 2,
    parts     => {
        A => \&part_A,
        B => \&part_B,
        C => \&part_C,
    },
    next_part => 'A',
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
    say 'part B';
    # choose a random prime to use by the hihat
    my ($p) = primes_list(\%primes);
    my %patterns = (
        closed => $mcr->euclid($p, $beats),
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1)],
        snare  => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 1 0)],
    );
    my $next = 'C';
    return $next, \%patterns;
}

sub part_C {
    say 'part C';
    # choose a random prime to use by the hihat
    my ($p, $q) = primes_list(\%primes);
    my %patterns = (
        closed => $mcr->euclid($p, $beats),
        open   => $mcr->euclid($q, $beats),
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 1 0 0 0 0 0)],
        snare  => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 0 0)],
    );
    my $next = 'A';
    return $next, \%patterns;
}

sub primes_list($primes) {
    return map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
}