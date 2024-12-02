#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Util qw(setup_score midi_format);
use Music::Scales qw(get_scale_notes);

my $root = 'C';

my $score = setup_score(patch => 4);

for my $mode (qw(lydian ionian mixolydian dorian aeolian phrygian locrian)) {
    my @scale = get_scale_notes($root, $mode);
    print "$mode: @scale\n";

    my $octave = 4;

    my @thirds;
    for my $n (0 .. $#scale) {
        push @thirds, $scale[ (2 * $n) % @scale ] . $octave;
        $octave++ if (@thirds % 5) == 4;
        $score->n('hn', midi_format(@thirds));
    }
    print "\t@thirds\n";

    $score->r('wn');
}

$score->write_score("$0.mid");

__END__
lydian:  C E  G  B  D  F# A  = Cmaj13#11
ionian:  C E  G  B  D  F  A  = Cmaj13
mixo:    C E  G  Bb D  F  A  = C13
dorian:  C Eb G  Bb D  F  A  = Cm13
aeolian: C Eb G  Bb D  F  Ab = Cmb13
phryg:   C Eb G  Bb Db F  Ab = Cm(b9,b13)
loc:     C Eb Gb Bb Db F  Ab = Cm(b5,b9,b13)
