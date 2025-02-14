#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Drummer::Tiny ();

my $x = shift || 4;
my $y = shift || 4;

my @rows = map { row($_) } 1 .. $y;

my $d = MIDI::Drummer::Tiny->new;

$d->sync(@rows);

$d->play_with_timidity;
# $d->write;

sub row {
    my ($n) = @_;
    my $bpm = random_item([70 .. 100]);
    my $reverb = 15 + $n;
    my $volume = 100 - $n;
    my $mdt = MIDI::Drummer::Tiny->new(
        bpm    => $bpm,
        reverb => $reverb,
        volume => $volume,
    );
    my @row;
    for my $i (1 .. $x) {
        push @row, sub { $mdt->count_in({ bars => 4, patch => $d->snare }) }
    }
    return \@row;
}

sub random_item {
    my ($items) = @_;
    return $items->[ int rand @$items ];
}
