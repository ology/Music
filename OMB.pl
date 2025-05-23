#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Drummer::Tiny ();
use Music::Duration::Partition ();

my $bpm = shift || 120; # Beats per minute

my $size = shift || 4; # Motif duration in quarter-notes
my $max  = shift || 4; # Repeats

my $d = MIDI::Drummer::Tiny->new(
    file   => "$0.mid",
    bpm    => $bpm,
    volume => 127,
    bars   => 4,
);

my @fills = map { my $sub = 'fill_' . $_; \&$sub } 1 .. 6;

$d->score->synch(
    \&hihat,
    \&kick,
    \&snare,
) for 1 .. $max;

$d->write;

sub hihat {
    my $roll = int rand 2; # "roll" as in dice
    my $pool = $roll ? [qw(tqn ten)] : [qw(qn en)];
    _part('Hihat', $d->closed_hh, $pool)
        for 1 .. $d->bars;
}

sub kick {
    my $roll = int rand 2; # "roll" as in dice
    my $pool = $roll ? [qw(qn en)] : [qw(hn dqn qn)];
    _part('Kick', $d->kick, $pool)
        for 1 .. $d->bars;
}

sub snare {
    for (1 .. $d->bars) {
        my $roll = int rand 2; # "roll" as in dice
        print "Snare: $roll\n";
        for (1 .. $d->bars - 1) {
            for my $n (1 .. $size) {
                if ($roll) {
                    if ($n % 2 == 0) {
                        $d->note('qn', $d->snare);
                    }
                    else {
                        $d->rest('qn');
                    }
                }
                else {
                    if ($n % 3 == 0) {
                        $d->note('qn', $d->snare);
                    }
                    else {
                        $d->rest('qn');
                    }
                }
            }
        }
        # Fill for a bar!
        fill();
    }
}

sub fill {
    my $mdp = Music::Duration::Partition->new(
        size    => $size,
        pool    => [qw(qn en sn)],
        weights => [5, 10, 5],
        groups  => [0, 0, 2],
    );
    my $motif = $mdp->motif;
    warn 'Fill: ', ddc($motif);
    my $fill = @fills[ int rand @fills ];
    for my $i (0 .. $#$motif) {
        my $patch = $fill->($i);
        $d->note($motif->[$i], $patch);
    }
}

# Descend the kit
sub fill_1 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare         if $i == 0 || $i == 1;
    $patch = $d->hi_tom        if $i == 2;
    $patch = $d->hi_mid_tom    if $i == 3;
    $patch = $d->low_mid_tom   if $i == 4;
    $patch = $d->low_tom       if $i == 5;
    $patch = $d->hi_floor_tom  if $i == 6;
    $patch = $d->low_floor_tom if $i == 7;
    return $patch;
}

# Descend the kit but alternate with the snare
sub fill_2 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare         if $i % 2 == 0;
    $patch = $d->hi_tom        if $i == 1;
    $patch = $d->hi_mid_tom    if $i == 3;
    $patch = $d->low_mid_tom   if $i == 5;
    $patch = $d->low_tom       if $i == 7;
    $patch = $d->hi_floor_tom  if $i == 9;
    $patch = $d->low_floor_tom if $i == 11;
    return $patch;
}

# Descend the kit in twos
sub fill_3 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare         if $i == 0  || $i == 1;
    $patch = $d->hi_tom        if $i == 2  || $i == 3;
    $patch = $d->hi_mid_tom    if $i == 4  || $i == 5;
    $patch = $d->low_mid_tom   if $i == 6  || $i == 7;
    $patch = $d->low_tom       if $i == 8  || $i == 9;
    $patch = $d->hi_floor_tom  if $i == 10 || $i == 11;
    $patch = $d->low_floor_tom if $i == 12 || $i == 13;
    return $patch;
}

# Descend the kit and possibly strike a cymbal
sub fill_4 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare                     if $i == 0 || $i == 1;
    $patch = _or_cymbal($d->hi_tom)        if $i == 2;
    $patch = _or_cymbal($d->hi_mid_tom)    if $i == 3;
    $patch = _or_cymbal($d->low_mid_tom)   if $i == 4;
    $patch = _or_cymbal($d->low_tom)       if $i == 5;
    $patch = _or_cymbal($d->hi_floor_tom)  if $i == 6;
    $patch = _or_cymbal($d->low_floor_tom) if $i == 7;
    return $patch;
}

# Descend the kit alternating with the snare but possibly strike a cymbal
sub fill_5 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare                     if $i % 2 == 0;
    $patch = _or_cymbal($d->hi_tom)        if $i == 1;
    $patch = _or_cymbal($d->hi_mid_tom)    if $i == 3;
    $patch = _or_cymbal($d->low_mid_tom)   if $i == 5;
    $patch = _or_cymbal($d->low_tom)       if $i == 7;
    $patch = _or_cymbal($d->hi_floor_tom)  if $i == 9;
    $patch = _or_cymbal($d->low_floor_tom) if $i == 11;
    return $patch;
}

# Descend the kit in twos but possibly strike a cymbal
sub fill_6 {
    my ($i) = @_;
    my $patch;
    $patch = $d->snare                     if $i == 0  || $i == 1;
    $patch = _or_cymbal($d->hi_tom)        if $i == 2  || $i == 3;
    $patch = _or_cymbal($d->hi_mid_tom)    if $i == 4  || $i == 5;
    $patch = _or_cymbal($d->low_mid_tom)   if $i == 6  || $i == 7;
    $patch = _or_cymbal($d->low_tom)       if $i == 8  || $i == 9;
    $patch = _or_cymbal($d->hi_floor_tom)  if $i == 10 || $i == 11;
    $patch = _or_cymbal($d->low_floor_tom) if $i == 12 || $i == 13;
    return $patch;
}

sub _part {
        my ($name, $note, $pool) = @_;
        # Instantiate a new rhythmic phrase generator
        my $mdp = Music::Duration::Partition->new(size => $size, pool => $pool);
        # Get a random rhythmic phrase
        my $motif = $mdp->motif;
        print "$name: ", ddc($motif);
        # Play the phrase for the number of bars less one
        for my $n (1 .. $d->bars - 1) {
            for my $duration (@$motif) {
                $d->note($duration, $note);
            }
        }
        # Rest while we fill
        $d->rest('wn');
}

sub _or_cymbal {
    my ($patch) = @_;
    my @cymbals = qw(crash1 crash2 splash china);
    my $cymbal = $cymbals[int rand @cymbals];
    # Return a cymbal 4/10 times
    return int(rand 10) < 4 ? $d->$cymbal : $patch;
}
