#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use List::Util qw(all);

my %opt = (
    mother => 'qn qn qn',
    father => 'hn qn qn qn qn hn',
    mutate => 0.6,
);
GetOptions(\%opt,
    'mother=s',
    'father=s',
);

my %rules = (
    hn => [
      'den en',
      'en den',
      'qn qn',
      'qn en en',
      'en qn en',
      'en en qn',
    ],
    qn => [
      'en en',
    ],
    en => [ 'en' ],
);
# warn __PACKAGE__,' L',__LINE__,' ',ddc(\%rules);exit;

my $mother = [ split /\s+/, $opt{mother} ];
my $father = [ split /\s+/, $opt{father} ];
warn __PACKAGE__,' L',__LINE__,' M: ',ddc($mother);

my $child = mutate_down(\%rules, $mother, $opt{mutate});
warn __PACKAGE__,' L',__LINE__,' C: ',ddc($child);

my %inverted = invert_rules(\%rules);
warn __PACKAGE__,' L',__LINE__,' ',ddc(\%inverted);

$child = mutate_up(\%inverted, $child, $opt{mutate});
warn __PACKAGE__,' L',__LINE__,' I: ',ddc($child);

# my $matches = subsequences($mother, $father);
# warn __PACKAGE__,' L',__LINE__,' ',ddc($matches, {max_width=>128});

sub invert_rules {
    my ($rules) = @_;
    my %invert;
    for my $rule (keys %$rules) {
        for my $item ($rules->{$rule}->@*) {
            $invert{$item} = [ $rule ];
        } 
    }
    return %invert;
}

sub mutate_up {
    my ($rules, $source, $probability) = @_;
    my @mutation = $source->@*;
    if (rand() <= $probability) {
        my @keys = keys %$rules;
warn __PACKAGE__,' L',__LINE__,' K: ',ddc(\@keys);
        my $n = @keys[ rand @keys ];
        my @ns = split /\s+/, $n;
warn __PACKAGE__,' L',__LINE__,' Ns: ',,"@ns\n";
        my $items = $rules->{$n};
warn __PACKAGE__,' L',__LINE__,' ',,"Is: @$items\n";
        my $item = $items->[ rand @$items ];
warn __PACKAGE__,' L',__LINE__,' ',,"I: $item\n";
        my @parts = split /\s+/, $item;
        if (my $subseqs = subsequences(\@ns, $source)) {
            my $seq_num = $subseqs->[ rand @$subseqs ];
warn __PACKAGE__,' L',__LINE__,' S: ',,"[@$subseqs] => $seq_num\n";
            splice @mutation, $seq_num, scalar(@ns), @parts
                if defined $seq_num;
        }
    }
    return \@mutation;
}

sub mutate_down {
    my ($rules, $source, $probability) = @_;
    my @mutation = $source->@*;
    if (rand() <= $probability) {
        my $n = rand @$source;
        my $item = $source->[$n];
        splice @mutation, $n, 1, rand_elem($rules->{$item})->@*;
    }
    return \@mutation;
}

sub rand_elem {
    my ($aref) = @_;
    my $elem = [ split /\s+/, $aref->[ rand @$aref ] ];
    return $elem;
}

sub subsequences {
    my ($needles, $haystack) = @_;
    my @indices;
    my $length = $needles->@*;
    if ($length > 0 && $haystack->@* >= $length) {
        my $i = 0;
        my $j = $haystack->@* - $length;
        while ($i <= $j) {
            if ($length == grep { $needles->[$_] eq $haystack->[$i + $_] } keys $needles->@*) {
                push @indices, $i;
            }
            ++$i;
        }
    }
    return \@indices;
}

