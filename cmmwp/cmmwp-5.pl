#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact 'ddc';
use MIDI::Util qw(setup_score);
use Music::Scales qw(get_scale_MIDI);

my @pitches = (
    get_scale_MIDI('C', 4, 'minor'),
    get_scale_MIDI('C', 5, 'minor'),
);

my $score = setup_score();

for my $i (1 .. 8) {
  my @chord = map { $pitches[int rand @pitches] } 1 .. 3;
  print ddc(\@chord);
  $score->n('hn', @chord);
  $score->r('hn');
}

$score->write_score("$0.mid");
