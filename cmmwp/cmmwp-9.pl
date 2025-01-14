#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Drummer::Tiny;

my $d = MIDI::Drummer::Tiny->new(
    file => "$0.mid",
    bars => 4,
);

$d->note(
    $d->quarter,
    $d->closed_hh,
    $_ % 2 ? $d->kick : $d->snare
) for 1 .. $d->beats * $d->bars;

$d->write;
