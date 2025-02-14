#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Drummer::Tiny ();

my $x = shift || 4;
my $y = shift || 4;

my $d = MIDI::Drummer::Tiny->new;

my @rows = map { row($_)->@* } 1 .. $y;

$d->sync(@rows);
use Data::Dumper::Compact qw(ddc);
warn __PACKAGE__,' L',__LINE__,' ',ddc([$d->score->Score], {max_width=>128});

$d->play_with_timidity;
# $d->write;

sub row {
    my ($n) = @_;
    my @subs;
    for (1 .. $x) {
        push @subs, sub {
            my $bpm = random_item([70 .. 100]);
            my $reverb = 15 + $n;
            my $volume = 100 - $n;
            my $mdt = MIDI::Drummer::Tiny->new(
                score  => $d->score,
                setup  => 0,
                bpm    => $bpm,
                reverb => $reverb,
                volume => $volume,
            );
            for (1 .. $mdt->beats) {
                $mdt->note($mdt->quarter, $mdt->snare);
            }
        };
    }
    return \@subs;
}

sub random_item {
    my ($items) = @_;
    return $items->[ int rand @$items ];
}
