#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use List::Util qw(all min);

my %opt = (
    mother  => 'qn hn hn qn hn',
    father  => 'qn hn qn qn qn hn',
    mutate  => 0.6,
    verbose => 1,
);
GetOptions(\%opt,
    'mother=s',
    'father=s',
    'verbose!',
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
);
warn 'Rules: ',ddc(\%rules) if $opt{verbose};

my %inverted = invert_rules(\%rules);
warn 'Inverted: ',ddc(\%inverted) if $opt{verbose};

my $mother = [ split /\s+/, $opt{mother} ];
my $father = [ split /\s+/, $opt{father} ];
print '1st mother: ',ddc($mother);
print '1st father ',ddc($father);

# my $matches = subsequences($mother, $father);
# warn 'Matches: ',ddc($matches) if $opt{verbose};

# my $child = mutate_down(\%rules, $mother, $opt{mutate});
# print '2nd: ',ddc($child);
# $child = mutate_up(\%inverted, $child, $opt{mutate});
# print '3rd: ',ddc($child);

my @mother_list = (1, 2, 3, 4, 5);
my @father_list = (6, 7, 8, 9, 10);
my ($child_mother, $child_father) = crossover($mother, $father);
print "Mother's child: ", ddc($child_mother);
print "Father's child: ", ddc($child_father);


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
        my $matched = 0;
        my %seen;
        my @keys = keys %$rules;
        my $n = @keys[ rand @keys ];
        while (!$matched && (keys %seen <= @keys)) {
            $seen{$n}++;
            my @ns = split /\s+/, $n;
            warn ' Ns: ',,"@ns\n" if $opt{verbose};
            if (my $subseqs = subsequences(\@ns, $source)) {
                my $seq_num = $subseqs->[ rand @$subseqs ];
                if (defined $seq_num) {
                    $matched = 1;
                    my $items = $rules->{$n};
                    warn "Is: @$items\n" if $opt{verbose};
                    my $item = $items->[ rand @$items ];
                    warn "I: $item\n" if $opt{verbose};
                    my @parts = split /\s+/, $item;
                    warn 'S: ',,"[@$subseqs] => $seq_num\n" if $opt{verbose};
                    splice @mutation, $seq_num, scalar(@ns), @parts;
                    last;
                }
            }
            $n = @keys[ rand @keys ];
            while ((keys %seen < @keys) && $seen{$n}) {
                $n = @keys[ rand @keys ];
            }
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

sub crossover {
    my ($mother, $father) = @_;
    my @mother = @$mother;
    my @father = @$father;
    my $mother_size = @mother;
    my $father_size = @father;
    my $min_size = min($mother_size, $father_size);
    my $point = int rand $min_size;
warn __PACKAGE__,' L',__LINE__,' ',,"P: $point\n";
    # Swap elements beyond the crossover point
    for my $i ($point .. $min_size - 1) {
        ($mother[$i], $father[$i]) = ($father[$i], $mother[$i]);
    }
    @mother = grep { defined } @mother;
    @father = grep { defined } @father;
    return \@mother, \@father;
}
