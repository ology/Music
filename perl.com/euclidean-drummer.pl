#!/usr/bin/env perl

# Play and clock a MIDI device, like a drum machine or sequencer.
# Examples:
#   perl euclidean-drummer.pl wavetable 90  # on windows
#   perl euclidean-drummer.pl fluidsynth 90 # with fluidsynth
#   perl euclidean-drummer.pl usb 100 -1    # multi-timbral device

use v5.36;

use Math::Prime::Util qw(primes);
use Music::CreatingRhythms (); # for euclidean beats
use Music::SimpleDrumMachine ();

my $port = shift || 'fluidsynth';
my $bpm  = shift || 90;
my $chan = shift // 9;

my $beats  = 16;
my %primes = ( # for computing patterns
    all  => primes($beats),
    to_5 => primes(5),
    to_7 => primes(7),
);

my $next_part;# = { A => 4, B => 3, C => 2 }; # change 2

my $mcr = Music::CreatingRhythms->new;

my $dm = Music::SimpleDrumMachine->new(
    port_name => $port,
    bpm       => $bpm,
    chan      => $chan,
    filling   => 0, # change 1: comment
    bars      => 4, # measures per part
    parts     => {
        A => \&part_A,
        B => \&part_B,
        C => \&part_C,
    },
    next_part => 'A', # change 2: use $next_part
    save      => 'euclidean-drummer.mid',
    verbose   => 1,
);

sub part_A {
    say 'Part A';
    my %patterns = (
        closed => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0)],
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0)],
        snare  => [qw(1 0 0 0 1 0 0 0 1 0 0 0 1 1 1 0)],
    );
    $next_part = 'B'; # change 2: comment
    return $next_part, \%patterns;
}

sub part_B {
    say 'Part B';
    # choose the first (all) prime list to use for the closed hihat
    my ($p) = primes_list();
    my %patterns = (
        closed => $mcr->euclid($p, $beats),
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1)],
        snare  => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 1 0)],
    );
    $next_part = 'C'; # change 2: comment
    return $next_part, \%patterns;
}

sub part_C {
    say 'Part C';
    # choose primes to use for the closed and open hihats
    my ($p, $q) = primes_list();
    my %patterns = (
        closed => $mcr->euclid($p, $beats),
        open   => $mcr->euclid($q, $beats),
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 1 0 0 0 0 0)],
        snare  => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 0 0)],
    );
    $next_part = 'A'; # change 2: comment
    return $next_part, \%patterns;
}

sub primes_list { # return a random prime for each sorted key
    return map { $primes{$_}[ int rand $primes{$_}->@* ] } sort keys %primes;
}