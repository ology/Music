#!/usr/bin/env perl
use strict;
use warnings;

use MIDI::Util qw(setup_score);
use Music::Scales qw(get_scale_notes);

my $root = 'C';

my $score = setup_score(patch => 4);

for my $mode (qw(ionian dorian phrygian lydian mixolydian aeolian locrian)) {
    my @scale = get_scale_notes($root, $mode);
    print "$mode: @scale\n";
    my @thirds;
    for my $n (0 .. $#scale) {
        push @thirds, $scale[ (2 * $n) % @scale ];
        $score->n('wn', @thirds);
    }
    print "\t@thirds\n";
}
$score->write_score("$0.mid");

__END__
ionian:  C E  G  B  D  F  A  = Cmaj13
dorian:  C Eb G  Bb D  F  A  = Cm13
phryg:   C Eb G  Bb Db F  Ab = Cm(b9,b13)
lydian:  C E  G  B  D  F# A  = Cmaj13#11
mixo:    C E  G  Bb D  F  A  = C13
aeolian: C Eb G  Bb D  F  Ab = Cmb13
loc:     C Eb Gb Bb Db F  Ab = Cm(b5,b9,b13)
