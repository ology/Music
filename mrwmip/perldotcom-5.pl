#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $mcr = Music::CreatingRhythms->new;

my $necklaces = $mcr->neck(8);

my $x_choice = $necklaces->[ int rand @$necklaces ];
my $y_choice = $necklaces->[ int rand @$necklaces ];
my $z_choice = $necklaces->[ int rand @$necklaces ];

my $score = setup_score(bpm => 120, channel => 9);

for (1 .. 4) { # repeats
    for my $i (0 .. $#$x_choice) { # pattern position
        my @notes;
        if ($x_choice->[$i]) {
            push @notes, 75; # claves
        }
        if ($y_choice->[$i]) {
            push @notes, 63; # hi_conga
        }
        if ($z_choice->[$i]) {
            push @notes, 64; # low_conga
        }
        $score->n('en', @notes);
    }
}

$score->write_score('perldotcom-5.mid');
