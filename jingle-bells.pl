#!/usr/bin/env perl

# Write-up: https://perladvent.org/2023/2023-12-01.html

use strict;
use warnings;

#use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util Music-MelodicDevice-Ornamentation); # local author libraries
use MIDI::Util qw(setup_score midi_format);
use Music::MelodicDevice::Ornamentation ();

# The number of notes before resetting the note counter
use constant MAX => 16;

# Sixteen measure fragment of "duration.pitch" notes
my @notes = qw(
    qn.E4 qn.E4 hn.E4
    qn.E4 qn.E4 hn.E4
    qn.E4 qn.G4 qn.C4 qn.D4
    wn.E4

    qn.F4 qn.F4 qn.F4 qn.F4
    qn.F4 qn.E4 qn.E4 qn.E4
    qn.E4 qn.D4 qn.D4 qn.E4
    hn.D4       hn.G4

    qn.E4 qn.E4 hn.E4
    qn.E4 qn.E4 hn.E4
    qn.E4 qn.G4 qn.C4 qn.D4
    wn.E4

    qn.F4 qn.F4 qn.F4 qn.F4
    qn.F4 qn.E4 qn.E4 qn.E4
    qn.G4 qn.G4 qn.F4 qn.D4
    wn.C4
);

# Setup a MIDI score to use for the "plain version"
my $melody = setup_score(bpm => 140);

# Add the notes to the score
$melody->n(split /\./, $_) for @notes;

# Write out the "plain" score as a MIDI file
$melody->write_score("$0-plain.mid");

# Setup a new MIDI score for the ornamented version
$melody = setup_score(bpm => 140); # start over!

# Setup a new musical ornament maker
my $ornament = Music::MelodicDevice::Ornamentation->new(
    scale_note => 'C',
    scale_name => 'major',
);

# Dazzle with musical ornamentation (based on beat position for now)
my %dazzle = (
     2 => sub { $ornament->mordent(@_, 1) },
     7 => sub { $ornament->trill(@_, 2, 1) },
    10 => sub { $ornament->turn(@_, 1) },
    13 => sub { $ornament->grace_note(@_, -1) },
);

# For each duration.note pair...
my $counter = 0;
for my $note (@notes) {
    my @note = split /\./, $note;

    # Add either an ornamented or a "plain" note to the score
    if (exists $dazzle{$counter}) {
        my $fancy = $dazzle{$counter}->(@note);
        my @fancy = map { [ midi_format(@$_) ] } @$fancy; # turn '#' into 's' and 'b' into 'f'
        $melody->n(@$_) for @fancy;
    }
    else {
        $melody->n(midi_format(@note));
    }

    # Increment the counter, or start over if we've reached the max
    $counter = $counter == MAX ? 0 : $counter + 1;
}

# Write out the "fancy" score as a MIDI file
$melody->write_score("$0-fancy.mid");
