#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $mcr = Music::CreatingRhythms->new;

my $comps = $mcr->compm(5, 3); # compositions of 5 with 3 elements
print ddc($comps, {max_width=>128});

my $seq = $mcr->int2b($comps);
print ddc($seq, {max_width=>128});

my $score = setup_score(bpm => 120, channel => 9);

for my $pattern ($seq->@*) {
    for my $bit (@$pattern) {
        if ($bit) {
            $score->n('en', 40);
        }
        else {
            $score->r('en');
        }
    }
}

$score->write_score('perldotcom-2.mid');
