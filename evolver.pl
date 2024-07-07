#!/usr/bin/env perl
use strict;
use warnings;
use if $ENV{USER} eq 'gene', lib => map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);

use Algorithm::Combinatorics qw(permutations);
use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Integer::Partition ();
use List::Util qw(all min sum0 uniq);
use MIDI::Util qw(dura_size midi_dump reverse_dump);

my %opt = (
    mother  => 'wn',
    father  => 'wn',
    mutate  => 0.6,
    factor  => 1, # scale durations
    dump    => 0, # show rules and exit
    verbose => 1,
);
GetOptions(\%opt,
    'mother=s',
    'father=s',
    'mutate=i',
    'factor=i',
    'dump',
    'verbose!',
);

my ($rules, $inverted) = build_rules([qw(wn dhn hn qn)]);

my ($mother, $father) = get_parents($opt{mother}, $opt{father});

my ($mother_dura, $father_dura) = get_durations($mother, $father);

my $crossover = int(rand sum0(@$mother_dura)) + 1;
warn "Beat crossover point: $crossover\n" if $opt{verbose};

my ($m_point, $f_point) = substitution($mother, $father, $mother_dura, $father_dura, $crossover);
unless ($mother->[$m_point] eq 'qn' && $father->[$f_point] eq 'qn') {
    ($mother_dura, $father_dura) = get_durations($mother, $father);
    ($m_point, $f_point) = substitution($mother, $father, $mother_dura, $father_dura, $crossover);
}

# my $matches = subsequences($mother, $father);
# warn 'Matches: ',ddc($matches) if $opt{verbose};

# my $child = mutate_down($rules, $mother, $opt{mutate});
# print '2nd: ',ddc($child);
# $child = mutate_up(\%inverted, $child, $opt{mutate});
# print '3rd: ',ddc($child);

my ($child_mother, $child_father) = crossover($mother, $father, $m_point, $f_point);
print "Mother's child: ", ddc($child_mother);
print "Father's child: ", ddc($child_father);

sub substitution {
    my ($mother, $father, $mother_dura, $father_dura, $x) = @_;

    # compute the mother iterator and division
    my ($i, $sum) = iter($x, $mother_dura);
    my $m_div = $sum - $x;
    # compute the father iterator and division
    (my $j, $sum) = iter($x, $father_dura);
    my $f_div = $sum - $x;
    warn __PACKAGE__,' L',__LINE__,' ',,"M/F divs: $m_div, $f_div\n";
    my ($m_incd, $f_incd) = (0, 0);
    if (($m_div <= 0) || ($i != $j && $mother_dura->[$i] != $father_dura->[$j])) {
        $m_div++;
        $m_incd++;
    }
    if (($f_div <= 0) || ($i != $j && $father_dura->[$j] != $mother_dura->[$i])) {
        $f_div++;
        $f_incd++;
    }
    my $m_size = $mother_dura->[$i] - $m_div;
    my $f_size = $father_dura->[$j] - $f_div;
    warn __PACKAGE__,' L',__LINE__,' ',,"Msize: $mother_dura->[$i] - $m_div = $m_size\n";
    warn __PACKAGE__,' L',__LINE__,' ',,"Fsize: $father_dura->[$j] - $f_div = $f_size\n";
    my $m_sub = gen_sub($m_div, $m_size, $mother, $mother_dura, $i, $m_incd);
    warn __PACKAGE__,' L',__LINE__,' ',,"Msub: @$m_sub\n";
    my $f_sub = gen_sub($f_div, $f_size, $father, $father_dura, $j, $f_incd);
    warn __PACKAGE__,' L',__LINE__,' ',,"Fsub: @$f_sub\n";
    # substitution
    splice @$mother, $i, 1, @$m_sub;
    splice @$father, $j, 1, @$f_sub;
    warn 'Mother substituted: ',ddc($mother);# if $opt{verbose};
    warn 'Father substituted: ',ddc($father);# if $opt{verbose};

    # recompute indices
    $mother_dura = [ map { dura_size($_) } @$mother ];
    warn 'Mother durations: ',ddc($mother_dura) if $opt{verbse};
    $father_dura = [ map { dura_size($_) } @$father ];
    warn 'Father durations: ',ddc($father_dura) if $opt{verbse};
    ($i) = iter($x, $mother_dura);
    ($j) = iter($x, $father_dura);

    return $i, $j;
}

sub get_durations {
    my ($mother, $father) = @_;
    my @mother_dura = map { dura_size($_) } @$mother;
    warn 'Mother durations: ',ddc(\@mother_dura) if $opt{verbse};
    my @father_dura = map { dura_size($_) } @$father;
    warn 'Father durations: ',ddc(\@father_dura) if $opt{verbse};
    die "Parents must be the same beat value\n"
        unless sum0(@mother_dura) == sum0(@father_dura);
    return \@mother_dura, \@father_dura;
}

sub get_parents {
    my ($m, $f) = @_;
    my $mother = [ split /\s+/, $opt{mother} ];
    my $father = [ split /\s+/, $opt{father} ];
    print '1st mother: ',ddc($mother);
    print '1st father: ',ddc($father);
    return $mother, $father;
}

sub build_rules {
    my ($knowns) = @_;
    my (%rules, %seen);
    for my $dura (qw(wn dhn hn qn)) {
        my $ip = Integer::Partition->new(dura_size($dura) * $opt{factor});
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
        my @durations;
        for my $p (@parts) {
            my @named;
            for (@$p) {
                my $x = $_ / $opt{factor};
                my $name = $rev->{$x};
                push @named, $name;
            }
            next if grep { !defined } @named;
            push @durations, join ' ', @named;
        }
        $rules{$dura} = \@durations if @durations;
    }
    warn 'Rules: ',ddc(\%rules) if $opt{dump};
    my %inverted = invert_rules(\%rules);
    warn 'Inverted: ',ddc(\%inverted) if $opt{dump};
    exit if $opt{dump};
    return \%rules, \%inverted;
}

sub gen_sub {
    my ($div, $size, $list, $duras, $n, $incd) = @_;
# warn __PACKAGE__,' L',__LINE__,' ',,"$n, $duras->[$n], $size, $incd\n";
    return $duras->[$n] % 2 && $size == 2 && !$incd
        ? [ (reverse_dump('length')->{1}) x $duras->[$n] ]
        : $div && $size
        ? [ reverse_dump('length')->{$size}, reverse_dump('length')->{$div} ]
        : $div
            ? [ reverse_dump('length')->{$div} ]
            : [ $list->[$n] ];
}

sub iter {
    my ($point, $dura) = @_;
    my ($i, $sum) = (0, 0);
    for my $n (@$dura) {
        $sum += $n;
        if ($point <= $sum) {
            warn "Index: $i: Sum: $sum, N: $n\n" if $opt{verbose};
            last;
        }
        $i++;
    }
    return $i, $sum;
}

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
    warn "Crossover point: $m_point, $f_point\n" if $opt{verbose};
    my @mother = ( @$mother[ 0 .. $m_point - 1 ], @$father[ $f_point .. $#$father ] );
    my @father = ( @$father[ 0 .. $f_point - 1 ], @$mother[ $m_point .. $#$mother ] );
    return \@mother, \@father;
}
