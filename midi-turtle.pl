#!/usr/bin/env perl

use v5.36;
use Data::Dumper::Compact qw(ddc);
use Data::Turtle;
use MIDI::Util qw(setup_score midi_format);
use Music::ScaleNote;

my $turtle = Data::Turtle->new;
my $score  = setup_score(bpm => 120);
my $msn    = Music::ScaleNote->new(scale_note => 'C', scale_name => 'major');

my $note = Music::Note->new('C4', 'ISO');

for (1 .. 8) {
    my @line = $turtle->forward(10);
    if ($turtle->pen_status) {
        my $dur = $line[3] > $line[1] ? 'qn' : 'en'; # crude duration pick

        $note = $msn->get_offset(note_name => $note->format('ISO'), note_format => 'ISO', offset => 1);

        $score->n($dur, midi_format($note->format('ISO')));
    }

    $turtle->right(45);
}

$score->write_score($0 . '.mid');