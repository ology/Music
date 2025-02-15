#!/usr/bin/env perl
use strict;
use warnings;

use Math::Logic qw(:NUM);
use MIDI::Util qw(setup_score);
use Music::Cadence;
use Music::Scales;
use Music::VoiceGen;

my $max    = shift || 16;
my $note   = shift || 'C';
my $type   = shift || 'major';
my $scale  = shift || 'pentatonic';
my $octave = shift || 4;
my $bpm    = shift || 100;
my $leads  = shift || '1 2 4 7';

my @leaders = split /\s+/, $leads;
my $true    = 100;
my @leads   = map { Math::Logic->new(-value => $_, -degree => $true) } @leaders;

my $quarter = 'qn';
my $half    = 'hn';

my @scale = get_scale_MIDI($note, $octave, $scale);

my $score = setup_score(bpm => $bpm);

my $mc = Music::Cadence->new(
    key    => $note,
    scale  => $type,
    octave => $octave,
    format => 'midinum',
);

my $voice = Music::VoiceGen->new(
    pitches   => \@scale,
    intervals => [qw/-4 -3 -2 2 3 4/],
);

for my $i (1 .. $max) {
    my @notes = map { $voice->rand } 1 .. 2;
    $score->n($quarter, $_) for @notes;

    if ($i % 4 == 0) {
        my @chosen = map { $leads[ int rand @leads ] } 1 .. 2;
        my $result = $chosen[0] & $chosen[1];
        my $chords = $mc->cadence(
            type    => 'half',
            leading => $result->as_string,
        );
        # $chords = clip($mc, $chords); # Remove a random note from the chord
        $score->n($half, @$_) for @$chords;
    }
}

my $chords = $mc->cadence(
    type      => 'deceptive',
    variation => 1 + int rand 2,
);
$score->n($half, @$_) for @$chords;

$chords = $mc->cadence(type => 'plagal');
$score->n($half, @$_) for @$chords;

$chords = $mc->cadence(type => 'perfect');
$score->n($half, @$_) for @$chords;

$score->write_score("$0.mid");

sub clip {
    my ($mc, $chords) = @_;
    my @chords;
    for my $chord (@$chords) {
        $chord = $mc->remove_notes([int rand @$chord], $chord);
        push @chords, $chord;
    }
    return \@chords;
}
