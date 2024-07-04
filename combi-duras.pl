#!/usr/bin/env perl
use strict;
use warnings;

use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);

use Algorithm::Combinatorics qw(variations_with_repetition);
use Getopt::Long qw(GetOptions);
use List::Util qw(min sum0);
use MIDI::Util qw(dura_size);

my %opt = (
    size => 4, # number of beats
    pool => 'dqn qn den en dsn sn', # possible phrase durations
);
GetOptions(\%opt,
    'size=i',
    'pool=s',
);

$opt{pool} = [ split /\s+/, $opt{pool} ];
my @durations = map { dura_size($_) } $opt{pool}->@*;
my $grain = $opt{size} / min(@durations);

my $n = 1;
for my $take (1 .. $grain) {
    my $i = variations_with_repetition($opt{pool}, $take);
    while (my $c = $i->next) {
        my @durations = map { dura_size($_) } @$c;
        my $sum = sum0(@durations);
        next unless $sum == $opt{size};
        print "$n. @$c\n";
        $n++;
    }
}
