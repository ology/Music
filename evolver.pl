#!/usr/bin/env perl
use strict;
use warnings;
use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);

use Algorithm::Combinatorics qw(permutations);
use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Integer::Partition ();
use List::Util qw(all min uniq);
use MIDI::Util qw(dura_size reverse_dump);

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

my $factor = 2;

my %rules;
my %seen;

for my $dura (qw(dhn hn)) {
    my $ip = Integer::Partition->new(dura_size($dura) * $factor);
    my @parts;
    while (my $p = $ip->next) {
        next if @$p <= 1;
        if (uniq(@$p) > 1) {
            my $iter = permutations($p);
            while (my $perm = $iter->next) {
                push @parts, $perm unless $seen{"@$perm"}++;
            }
        }
        else {
            push @parts, $p unless $seen{"@$p"}++;
        }
    }
    # print "$dura: ",ddc(\@parts);
    my $rev = reverse_dump('length');
    my @z;
    for my $x (@parts) {
        my @temp;
        for (@$x) {
            my $f = $_ / $factor;
            my $y = $rev->{$f};
            push @temp, $y;
        }
        next if grep { !defined } @temp;
        push @z, join ' ', @temp;
    }
    $rules{$dura} = \@z;
}
warn __PACKAGE__,' L',__LINE__,' ',ddc(\%rules);
exit;

my %inverted = invert_rules(\%rules);
warn 'Inverted: ',ddc(\%inverted) if $opt{verbose};

my $mother = [ split /\s+/, $opt{mother} ];
my $father = [ split /\s+/, $opt{father} ];
print '1st mother: ',ddc($mother);
print '1st father: ',ddc($father);

my @mother_dura = map { dura_size($_) } @$mother;
warn __PACKAGE__,' L',__LINE__,' ',ddc(\@mother_dura);
my @father_dura = map { dura_size($_) } @$father;
warn __PACKAGE__,' L',__LINE__,' ',ddc(\@father_dura);
my $x = int rand 8;
warn __PACKAGE__,' L',__LINE__,' ',,"X: $x\n";
my $sum = 0;
my $i = 0;
for my $n (@mother_dura) {
    $sum += $n;
    if ($x <= $sum) {
        if ($n == 2) {
            splice @$mother, $i, 1, qw(qn qn);
            $i++ if $x == $sum;
        }
        warn "$i: $sum, $n\n";
        last;
    }
    $i++;
}
warn __PACKAGE__,' L',__LINE__,' M: ',ddc($mother);
$sum = 0;
my $j = 0;
for my $n (@father_dura) {
    $sum += $n;
    if ($x <= $sum) {
        if ($n == 2) {
            splice @$father, $j, 1, qw(qn qn);
            $j++ if $x == $sum;
        }
        warn "$j: $sum, $n\n";
        last;
    }
    $j++;
}
warn __PACKAGE__,' L',__LINE__,' F: ',ddc($father);

# my $matches = subsequences($mother, $father);
# warn 'Matches: ',ddc($matches) if $opt{verbose};

# my $child = mutate_down(\%rules, $mother, $opt{mutate});
# print '2nd: ',ddc($child);
# $child = mutate_up(\%inverted, $child, $opt{mutate});
# print '3rd: ',ddc($child);

my ($child_mother, $child_father) = crossover($mother, $father, $i, $j);
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
    my ($mother, $father, $m_point, $f_point) = @_;
warn __PACKAGE__,' L',__LINE__,' ',,"P: $m_point, $f_point\n";
    my @mother = @$mother;
    my @father = @$father;
    my $mother_size = @mother;
    my $father_size = @father;
    my $min_size = min($mother_size, $father_size);
    # Swap elements beyond the crossover point
    while ($m_point < $mother_size && $f_point < $father_size) {
        if ($mother[$m_point] eq $father[$f_point]) {
            $m_point++;
            $f_point++;
            next;
        }
        if ($mother[$m_point] eq 'hn' && $father[$f_point] eq 'qn' && $father[$f_point + 1] eq 'qn') {
            splice @mother, $m_point, 1, qw(qn qn);
            splice @father, $f_point, 2, qw(hn);
        }
        elsif ($father[$f_point] eq 'hn' && $mother[$m_point] eq 'qn' && $mother[$m_point + 1] eq 'qn') {
            splice @father, $f_point, 1, qw(qn qn);
            splice @mother, $m_point, 2, qw(hn);
        }
        $m_point++;
        $f_point++;
    }
    @mother = grep { defined } @mother;
    @father = grep { defined } @father;
    return \@mother, \@father;
}
