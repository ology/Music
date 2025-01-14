#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact 'ddc';
use MIDI::Util qw(setup_score);
use Music::Chord::Progression;

my $score = setup_score();

my $prog = Music::Chord::Progression->new;
my $chords = $prog->generate;
print ddc($chords);

$score->n('wn', @$_) for @$chords;

$score->write_score("$0.mid");
