#!/usr/bin/env perl
use v5.36;

use MIDI::Util qw(setup_score play_timidity);

my $bpm = shift || 100;

my %scale = map { $_ => 1 } (0, 2, 4, 5, 7, 9, 11); # Semitones in C Major

# Tenney Height / Dissonance Metric: Simplest ratios = lower score
# Standard ratios for intervals
my %interval_dissonance = (
    0  => 0,    # Unison (1:1)
    1  => 9.23, # Minor 2nd (16:15)
    2  => 6.17, # Major 2nd (9:8) - Dissonant
    3  => 4.91, # Minor 3rd (6:5)
    4  => 4.32, # Major 3rd (5:4)
    5  => 3.58, # Perfect 4th (4:3)
    6  => 8.81, # Tritone (45:32) - Very Dissonant
    7  => 2.58, # Perfect 5th (3:2)
    8  => 5.32, # Minor 6th (8:5)
    9  => 3.91, # Major 6th (5:3)
    10 => 5.49, # Minor 7th (16:9)
    11 => 6.91, # Major 7th (15:8)
    12 => 1,    # Octave (2:1)
);

# --- The Musical Particle ---
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

# --- The Objective Function ---
my $musical_fitness = sub ($notes) {
    my $score = 0;
    my @sorted = sort { $a <=> $b } @$notes;

    for my $i (0 .. $#sorted) {
        # 1. Penalty for notes NOT in C Major scale
        $score += 500 if !$scale{ $sorted[$i] % 12 };

        # 2. Consonance of pairwise intervals (i vs j)
        for my $j ($i + 1 .. $#sorted) {
            my $interval = ($sorted[$j] - $sorted[$i]) % 12;
            $score += $interval_dissonance{$interval} // 100;
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

# --- Optimization ---
package Swarm {
    use v5.36;
    use List::Util qw(min max);

    sub search ($objective, $iters=100) {
        my @swarm = map { ChordParticle->new([48, 72]) } 1 .. 30; # Range: C3 to C5
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

my %note_names = (
    0=>'C', 1=>'C#', 2=>'D', 3=>'Eb', 4=>'E', 5=>'F', 6=>'F#', 7=>'G', 8=>'Ab', 9=>'A', 10=>'Bb', 11=>'B'
);

my $score = setup_score(bpm => $bpm, patch => 5);

for my $i (1 .. 8) {
    my ($chord, $fitness) = Swarm::search($musical_fitness, 50);
    my @vec = map { $note_names{ $_ % 12 } . int( $_ / 12 ) } sort { $a <=> $b } @$chord;

    say "$i. Optimized Chord: ", join '-', @vec;
    say "\tFinal Dissonance Score: $fitness (Lower is more consonant)";

    $score->n('wn', @vec);
}

$score->write_score("$0.mid");
play_timidity($score, "$0.mid");
