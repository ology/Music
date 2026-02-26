#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $patch = shift || 75; # claves

my $mcr = Music::CreatingRhythms->new;

my $necklaces = $mcr->neck(8);
my $choice = $necklaces->[ int rand @$necklaces ];
print ddc($choice);

my $score = setup_score(bpm => 120, channel => 9);

for (1 .. 4) { # repeats
    for my $bit (@$choice) {
        if ($bit) {
            $score->n('en', $patch);
        }
        else {
            $score->r('en');
        }
    }
}

$score->write_score('perldotcom-4.mid');
