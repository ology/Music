#!/usr/bin/env perl
use strict;
use warnings;

# use Data::Dumper::Compact qw(ddc);
use Music::Note ();
use Music::VoiceGen ();

my $n         = shift || die "Usage: perl $0 n pitches intervals";
my $pitches   = shift || die "Usage: perl $0 n pitches intervals";
my $intervals = shift || die "Usage: perl $0 n pitches intervals";

$pitches =~ s/[\[\]]//g;
$intervals =~ s/[\[\]]//g;
# print ddc($pitches);
# print ddc($intervals);

my @pitches   = split /,/, $pitches;
my @intervals = split /,/, $intervals;

my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => \@intervals,
);

my @voices = map { $voice->rand } 1 .. $n;

for my $voice (@voices) {
    my $mn = Music::Note->new($_, 'midinum');
}

print join ',', map { Music::Note->new($_, 'midinum')->format('ISO') } @voices;
