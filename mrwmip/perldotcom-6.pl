#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $mcr = Music::CreatingRhythms->new;

my $beats = 16;

my $s_seq = $mcr->rotate_n(4, $mcr->euclid(2, $beats)); # snare
print ddc($s_seq);
my $k_seq = $mcr->euclid(2, $beats); # kick
print ddc($k_seq);
my $h_seq = $mcr->euclid(11, $beats); # hi-hats
print ddc($h_seq);

my $score = setup_score(bpm => 120, channel => 9);

for (1 .. 4) { # repeats
    for my $i (0 .. $beats - 1) { # pattern position
        my @notes;
        if ($s_seq->[$i]) {
            push @notes, 40; # snare
        }
        if ($k_seq->[$i]) {
            push @notes, 36; # kick
        }
        if ($h_seq->[$i]) {
            push @notes, 42; # hi-hats
        }
        if (@notes) {
            $score->n('en', @notes);
        }
        else {
            $score->r('en');
        }
    }
}

$score->write_score('perldotcom-6.mid');
