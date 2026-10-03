#!/usr/bin/env perl

# Play and clock a MIDI device, like a drum machine or sequencer.
# Examples:
#   perl euclidean-drummer.pl 'gs wavetable' 90 # on windows
#   perl euclidean-drummer.pl synth 90          # with fluidsynth
#   perl euclidean-drummer.pl usb 100 -1        # multi-timbral device

use v5.36;

use Math::Prime::XS qw(primes);
use Music::CreatingRhythms (); # for euclidean beats
use Music::SimpleDrumMachine ();

my $port = shift || 'usb';
my $bpm  = shift || 90;
my $chan = shift // 9;

my $beats  = 16;
my @primes = primes($beats);
my %primes = ( # for computing patterns
    all  => \@primes,
    to_5 => [@primes[0 .. 2]],
    to_7 => [@primes[0 .. 3]],
);

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
    say 'Part B';
    # choose the first (all) prime list to use for the closed hihat
    my ($p) = primes_list();
    my %patterns = (
        closed => $mcr->euclid($p, $beats),
        kick   => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1)],
        snare  => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 1 0)],
    );
    my $next = 'C';
    return $next, \%patterns;
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
    my $next = 'A';
    return $next, \%patterns;
}

# return the primes sorted by key name
sub primes_list {
    return map { $primes{$_}[ int rand $primes{$_}->@* ] } sort keys %primes;
}