#!/usr/bin/env perl

use v5.36;
use Data::Dumper::Compact qw(ddc);
use Data::Turtle;
use MIDI::Util qw(setup_score midi_format);
use Music::ScaleNote;

my $turtle = Data::Turtle->new;
my $score  = setup_score(bpm => 120);
my $msn    = Music::ScaleNote->new(scale_note => 'C', scale_name => 'major');
my $note   = Music::Note->new('C4', 'ISO');

phrase($turtle, $score, $msn, $note, 'right');
phrase($turtle, $score, $msn, $note, 'left');
phrase($turtle, $score, $msn, $note, 'right');
phrase($turtle, $score, $msn, $note, 'left');

$score->write_score($0 . '.mid');

sub phrase ($turtle, $score, $msn, $note, $direction) {
    for (1 .. 16) {
        my @line = $turtle->forward(10);
        my $dura = $line[3] > $line[1] ? 'qn' : 'en'; # crude duration pick
        if ($turtle->pen_status) {
            $note = $msn->get_offset(
                note_name   => $note->format('ISO'),
                note_format => 'ISO',
                offset      => rand > 0.5
                    ? (rand > 0.5 ? 2 : -2)
                    : (rand > 0.5 ? 1 : -1),
            );
            $score->n($dura, midi_format($note->format('ISO')));
        }
        else {
            $score->r($dura);
        }
        $turtle->$direction(45);
        $turtle->pen_status(rand > 0.2 ? 1 : 0); # rest = 20%
    }
}