#!/usr/bin/env perl
use v5.36;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::Scales qw(get_scale_notes get_scale_nums);
use Music::Tension::Cope ();

package ChordParticle {
    use v5.36;

    sub new ($class, $range) {
        bless {
            pos   => [ map { int(rand($range->[1] - $range->[0])) + $range->[0] } 1 .. 3 ],
            vel   => [ map { rand(4) - 2 } 1 .. 3 ],
            pbest => undef,
            score => 1e18,
        }, $class;
    }
}

package Swarm {
    use v5.36;
    use List::Util qw(min max);

    sub search ($objective, $iters=100) {
        my @swarm = map { ChordParticle->new([48, 72]) } 1 .. 30; # C3 to C5
        my ($gbest_pos, $gbest_score) = ([], 1e18);

        for (1 .. $iters) {
            for my $p (@swarm) {
                my $s = $objective->($p->{pos});
                if ($s < $p->{score}) {
                    $p->{score} = $s;
                    $p->{pbest} = [ $p->{pos}->@* ];
                }
                if ($s < $gbest_score) {
                    $gbest_score = $s;
                    $gbest_pos = [ $p->{pos}->@* ];
                }
            }
            # Movement logic
            for my $p (@swarm) {
                for my $d (0..2) {
                    $p->{vel}[$d] = 0.5 * $p->{vel}[$d] +
                                    rand() * ($p->{pbest}[$d] - $p->{pos}[$d]) +
                                    rand() * ($gbest_pos->[$d] - $p->{pos}[$d]);
                    $p->{pos}[$d] = int(max(48, min(72, $p->{pos}[$d] + $p->{vel}[$d])));
                }
            }
        }
        return ($gbest_pos, $gbest_score);
    }
}

my $bpm = shift || 100;

my %scale = map { $_ => 1 } get_scale_nums('major'); # Semitones in C Major

my $tension = Music::Tension::Cope->new;

# --- The Objective Function ---
my $musical_fitness = sub ($notes) {
    my $score = 0;
    my @sorted = sort { $a <=> $b } @$notes;

    for my $i (0 .. $#sorted) {
        # 1. Penalty for notes NOT in C Major scale
        $score += 500 if !$scale{ $sorted[$i] % 12 };

        # 2. Consonance of pairwise intervals (i vs j)
        for my $j ($i + 1 .. $#sorted) {
            $score += $tension->vertical([$sorted[$i], $sorted[$j]]) // 100;
        }
    }

    # 3. Penalty for unison notes
    $score += 1000 if $sorted[0] == $sorted[1] || $sorted[1] == $sorted[2];

    # 4. Penalty for octave notes
    $score += 1000 if abs($sorted[1] - $sorted[0]) % 12 == 0 ||
                      abs($sorted[2] - $sorted[0]) % 12 == 0 ||
                      abs($sorted[2] - $sorted[1]) % 12 == 0;

    return $score;
};

my $n = 0;
my %note_names = map { $n++ => $_ } get_scale_notes('C', 'Chromatic');

my $score = setup_score(bpm => $bpm, patch => 5);

for my $i (1 .. 8) {
    my ($chord, $fitness) = Swarm::search($musical_fitness);
    my @notes = map { $note_names{ $_ % 12 } . int( $_ / 12 ) } sort { $a <=> $b } @$chord;

    say "$i. Optimized Chord: ", join '-', @notes;
    say "\tFinal Dissonance Score: $fitness (Lower is more consonant)";

    $score->n('wn', @notes);
}

$score->write_score("$0.mid");