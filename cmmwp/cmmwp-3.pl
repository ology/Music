#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Util qw(setup_score set_chan_patch);

my $score = setup_score();

$score->synch(
  sub { bass($score) },
  sub { treble($score) },
) for 1 .. 4;

$score->write_score("$0.mid");

sub bass {
  my ($score) = @_;
  for my $note (qw(C3 F3 G3 C4)) {
    $score->n('qn', $note);
  }
}

sub treble {
  set_chan_patch($score, 1, 0);

  my @pitches = (60, 62, 64, 65, 67, 69, 71, 72);

  for my $n (1 .. 4) {
    my $pitch = $pitches[int rand @pitches];
    $score->n('en', $pitch);
    $score->r('en');
  }
}
