#!/usr/bin/env perl

# THIS IS CALLED BY random-rhythms.py !!

use strict;
use warnings;

use Music::Note ();
use Music::VoiceGen ();

my $n         = shift || die "Usage: perl $0 n pitches intervals";
my $pitches   = shift || die "Usage: perl $0 n pitches intervals";
my $intervals = shift || die "Usage: perl $0 n pitches intervals";

$pitches   =~ s/[\[\]]//g;
$intervals =~ s/[\[\]]//g;

my @pitches   = split /,/, $pitches;
my @intervals = split /,/, $intervals;

my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => \@intervals,
);

my @voices = map { $voice->rand } 1 .. $n;

print join ',', map { Music::Note->new($_, 'midinum')->format('ISO') } @voices;
