#!/usr/bin/env perl

use v5.36;
use Data::Dumper::Compact qw(ddc);
use Data::Turtle;
use MIDI::Util qw(setup_score midi_format);
use Music::ScaleNote;

my $bpm     = shift || 120;
my $base    = shift || 'C';
my $scale   = shift || 'major';
my $octave  = shift || 4;
my $verbose = shift || 1;

my $turtle = Data::Turtle->new;
my $score  = setup_score(bpm => $bpm);
my $msn    = Music::ScaleNote->new(scale_note => $base, scale_name => $scale);
my $note   = Music::Note->new($base . $octave, 'ISO');

for (1 .. 4) {
    phrase($turtle, $score, $msn, $note, 'right');
    phrase($turtle, $score, $msn, $note, 'left');
    phrase($turtle, $score, $msn, $note, 'right');
    phrase($turtle, $score, $msn, $note, 'left');
}
$score->n('wn', $base . $octave);

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
            my @n = midi_format($note->format('ISO'));
            say "Note: $dura, @n" if $verbose;
            $score->n($dura, @n);
        }
        else {
            say "Rest: $dura" if $verbose;
            $score->r($dura);
        }
        $turtle->$direction(45);
        $turtle->pen_status(rand > 0.1 ? 1 : 0); # rest = 10%
    }
}