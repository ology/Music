#!/usr/bin/env perl
use v5.36;
use List::Util qw(sum);
use Math::Trig qw(pi);

# psychoacoustic model
use constant {
    RESOLUTION => 0.01,   # Pitch resolution in semitones (approx. 1 cent)
    MAX_DENOM  => 12,     # Farey Series order (limits ratio complexity)
    LOG2       => log(2),
};

# Farey Series (candidate ratios) up to a max denominator
sub generate_farey_ratios ($n) {
    my %ratios;
    for my $q (1 .. $n) {
        for my $p (1 .. $n * 2) { # Octave-equivalent and slightly beyond
            $ratios{$p / $q} = [$p, $q];
        }
    }
    return sort { $a <=> $b } keys %ratios;
}

# probability density function (Gaussian) for perceived pitch
# x: candidate ratio, mu: actual interval, s: standard deviation (uncertainty)
sub normal_pdf ($x, $mu, $s) {
    return (1 / ($s * sqrt(2 * pi))) * exp(-0.5 * (($x - $mu) / $s)**2);
}

sub harmonic_entropy ($p1, $p2, $sigma = 0.05) {
    my $target_ratio = $p1 / $p2;
    my @ratios = generate_farey_ratios(MAX_DENOM);
    
    # calculate probabilities for each ratio candidate
    my @probs;
    for my $r (@ratios) {
        push @probs, normal_pdf($r, $target_ratio, $sigma);
    }
    
    # normalize probabilities
    my $total = sum(@probs);
    @probs = map { $_ / $total } @probs;
    
    # Shannon entropy
    my $entropy = 0;
    for my $p (@probs) {
        next if $p == 0; # log(0) undefined
        $entropy -= $p * (log($p) / LOG2);
    }
    return $entropy;
}

my ($num, $den) = @ARGV;
if (!$num || !$den) {
    say "Usage: $0 <numer> <denom>";
    say "Example: $0 3 2 # Perfect Fifth";
    exit;
}

my $h = harmonic_entropy($num, $den);
printf "Interval %d:%d\n", $num, $den;
printf "Harmonic Entropy (Sigma=0.05): %.4f bits\n", $h;

