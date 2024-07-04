#!/usr/bin/env perl
use strict;
use warnings;

use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);

use AI::Genetic ();
use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use List::Util qw(pairs sum0);
use MIDI::Util qw(dura_size);

my %opt = (
    type       => 'listvector',
    population => 4,
    crossover  => 0.9,  # probability of crossover
    mutation   => 0.01, # probability of mutation
);
GetOptions(\%opt,
    'population=i',
    'crossover=i',
    'mutation=i',
);

sub fitness {
    my ($chromosome) = @_;
# warn __PACKAGE__,' L',__LINE__,' ',ddc($chromosome, {max_width=>128});
    my @durations;
    for my $pair (pairs @$chromosome) {
        next if $pair->[0] eq '0' || $pair->[1] eq '0';
        push @durations, dura_size($pair->[0]);
    }
warn __PACKAGE__,' L',__LINE__,' ',ddc(\@durations, {max_width=>128});
    my $sum = sum0(@durations);
warn __PACKAGE__,' L',__LINE__,' ',,"S: $sum\n";
    return $sum;
}

sub terminate {
    my ($ga) = @_;
# warn __PACKAGE__,' L',__LINE__,' ',ddc($ga->people, {max_width=>128});exit;
# warn __PACKAGE__,' L',__LINE__,' ',$ga->getFittest->score,"\n";
    my $threshold = 4;
    return $ga->getFittest->score == $threshold ? 1 : 0;
}

my $ga = AI::Genetic->new(
    -type       => $opt{type},       # type of chromosomes
    -population => $opt{population}, # population
    -crossover  => $opt{crossover},  # probab. of crossover
    -mutation   => $opt{mutation},   # probab. of mutation
    -fitness    => \&fitness,        # fitness function
    -terminate  => \&terminate,      # terminate function
);

# init population of listvectors
$ga->init([
    map { [qw(hn dqn qn den en 0)], [qw(C4 D4 E4 F4 G4 A4 B4 0)] } 1 .. 8
]);
# warn __PACKAGE__,' L',__LINE__,' ',ddc($ga->people);

# $ga->evolve('rouletteTwoPoint', 1);
# warn __PACKAGE__,' L',__LINE__,' ',ddc($ga->people);

# print 'Fittest: ', ddc($ga->getFittest, {max_width=>128});

__END__
