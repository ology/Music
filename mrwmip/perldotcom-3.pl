#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::Util qw(setup_score);
use Music::CreatingRhythms ();

my $mcr = Music::CreatingRhythms->new;

my $s_comps = $mcr->compm(4, 2); # snare
print ddc($s_comps);
my $s_seq = $mcr->int2b($s_comps);
print ddc($s_seq);

my $k_comps = $mcr->compm(4, 3); # kick
print ddc($k_comps);
my $k_seq = $mcr->int2b($k_comps);
print ddc($k_seq);

my $score = setup_score(bpm => 120, channel => 9);

for (1 .. 8) { # repeats
    my $s_choice = $s_seq->[ int rand @$s_seq ];
    print ddc($s_choice);
    my $k_choice = $k_seq->[ int rand @$k_seq ];
    print ddc($k_choice);

    for my $i (0 .. $#$s_choice) { # pattern position
        my @notes = (42); # hi-hat every time
        if ($s_choice->[$i]) {
            push @notes, 40;
        }
        if ($k_choice->[$i]) {
            push @notes, 36;
        }
        $score->n('en', @notes);
    }
}

$score->write_score('perldotcom-3.mid');
