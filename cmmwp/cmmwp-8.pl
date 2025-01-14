#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Util qw(setup_score);
use Music::Duration::Partition ();
use Music::Scales qw(get_scale_MIDI);
use Music::VoiceGen ();

my $score = setup_score();

# get rhythmic phrases
my $mdp = Music::Duration::Partition->new(
    size => 4, # 1 measure in 4/4
    pool => [qw(hn dqn qn en)],
);
my @motifs = $mdp->motifs(4);

# assign voices to the rhythmic motifs
my @pitches = (
  get_scale_MIDI('C', 4, 'minor'),
  get_scale_MIDI('C', 5, 'minor'),
);
my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => [qw(-3 -2 -1 1 2 3)],
);
my @voices;
for my $motif (@motifs) {
    my @notes = map { $voice->rand } @$motif;
    push @voices, \@notes;
}

for (1 .. 4) { # repeat the phrases 4 times
    for my $n (0 .. $#motifs) {
        $mdp->add_to_score($score, $motifs[$n], $voices[$n]);
    }
}

$score->write_score("$0.mid");
