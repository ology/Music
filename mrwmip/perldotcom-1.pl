#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $mcr = Music::CreatingRhythms->new;

my $parts = $mcr->part(5);
print ddc($parts);
my $p = $parts->[2];
print ddc($p);

my $seq = $mcr->int2b([$p]);
print ddc($seq);

my $score = setup_score(bpm => 120, channel => 9);

for (1 .. 4) {
    for my $bit ($seq->[0]->@*) {
        if ($bit) {
            $score->n('en', 40);
        }
        else {
            $score->r('en');
        }
    }
}

$score->write_score('perldotcom-1.mid');
