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
use Data::Dumper::Compact qw(ddc);
warn __PACKAGE__,' L',__LINE__,' ',ddc(\%rules);exit;

my $mother = [ split /\s+/, $opt{mother} ];
my $father = [ split /\s+/, $opt{father} ];
warn __PACKAGE__,' L',__LINE__,' M: ',ddc($mother, {max_width=>128});

my $child = mutate_down(\%rules, $mother, $opt{mutate});
warn __PACKAGE__,' L',__LINE__,' C: ',ddc($child, {max_width=>128});

my %inverted = invert_rules(\%rules);
warn __PACKAGE__,' L',__LINE__,' ',ddc(\%inverted, {max_width=>128});

$child = mutate_up(\%inverted, $child, $opt{mutate});
warn __PACKAGE__,' L',__LINE__,' I: ',ddc($child, {max_width=>128});

# my $matches = contiguous_subsequences($mother, $father);
# my $matches = tirnanog($mother, $father);
# my $matches = botje($mother, $father);
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
warn __PACKAGE__,' L',__LINE__,' K: ',ddc(\@keys, {max_width=>128});
        my $n = @keys[ rand @keys ];
        my @ns = split /\s+/, $n;
warn __PACKAGE__,' L',__LINE__,' Ns: ',,"@ns\n";
        my $items = $rules->{$n};
warn __PACKAGE__,' L',__LINE__,' ',,"Is: @$items\n";
        my $item = $items->[ rand @$items ];
warn __PACKAGE__,' L',__LINE__,' ',,"I: $item\n";
        my @parts = split /\s+/, $item;
        if (my $subseqs = botje(\@ns, $source)) {
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

sub contiguous_subsequences {
    my ($little_set, $big_set) = @_;
    my $little_set_size = @$little_set;
    my $big_set_size    = @$big_set;
    my @matches;
    my $i = 0; # little set index
    my $j = 0; # big set index
    my $k = 0; # matches found
    my $p = 0; # initial big set position
    my $f = 0; # failed to find match
    while ($i < $little_set_size && $j < $big_set_size) {
        if ($little_set->[$i] eq $big_set->[$j]) {
            $k++;   # We match
            $j++;   # Move to the next element in the big_set
            $f = 0; # failed to find match
        }
        else {
            $f++;
        }
        $i++;  # Move to the next element in the little_set
        if ($f || $i >= $little_set_size) {
            push @matches, $p if $k == $little_set_size;
            $p++;    # increment the big set position
            $i = 0;  # reset the little set position
            $j = $p; # set the big set index to the big set position
            $k = 0;  # no matches seen
        }
    }
    return \@matches;
}

sub tirnanog {
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

sub botje {
    my ($needles, $haystack) = @_;
    return () unless $needles->@*;
    my @results = grep {
        my $i = $_;
        $needles->@* == grep { $needles->[$_] eq $haystack->[$i + $_] } keys $needles->@*;
    } 0 .. $haystack->$#* - $needles->$#*;
    return \@results;
}

