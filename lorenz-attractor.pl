#!/usr/bin/env perl
use v5.36;

use Math::Utils qw(uniform_scaling);
use MIDI::Util qw(setup_score);
use Music::Note ();

# ── Lorenz parameters ──────────────────────────────────────────────
use constant SIGMA => 10;
use constant RHO   => 28;
use constant BETA  => 8/3;

# ── MIDI ──────────────────────────-------------────────────────────
my $midi_range = [48, 83];  # allowed MIDI pitches
my $x_range    = [-25, 25]; # x-axis scale
my $yz_range   = [0, 50];   # y- & z-axis scale

my $score = setup_score(patch => 4);

# ── RK4 integrator ────────────────────────────────────────────────
sub vec_add_scale ($i, $j, $s) { [ map { $i->[$_] + $j->[$_] * $s } 0 .. $#$i ] }
sub rk4 ($f, $t, $y, $dt) {
    my $k1 = $f->($t, $y);
    my $k2 = $f->($t + $dt/2, vec_add_scale($y, $k1, $dt/2));
    my $k3 = $f->($t + $dt/2, vec_add_scale($y, $k2, $dt/2));
    my $k4 = $f->($t + $dt, vec_add_scale($y, $k3, $dt));
    return [
        map {
            $y->[$_] + ($dt/6) * ($k1->[$_] + 2*$k2->[$_] + 2*$k3->[$_] + $k4->[$_])
        } 0 .. $#$y
    ];
}

# ── Lorenz system ─────────────────────────────────────────────────
my $lorenz = sub ($t, $y) {
    my ($x, $yy, $z) = @$y;
    return [
        SIGMA * ($yy - $x),
        $x * (RHO - $z) - $yy,
        $x * $yy - BETA * $z,
    ]
};

# ── Initial conditions ────────────────────────────────────────────
my $t     = 0.0;
my $t_end = 50.0;
my $dt    = 0.01;
my $y     = [1.0, 1.0, 1.0];    # initial [x, y, z]

# ── Solve ----------------─────────────────────────────────────────
open my $fh, '>', "$0.csv" or die "Cannot open csv: $!";
say $fh 't,x,y,z';

while ($t <= $t_end) {
    say $fh join ',', map { sprintf '%.8g', $_ } $t, @$y;
    $y = rk4($lorenz, $t, $y, $dt);
    $t += $dt;
    # XXX naive
    my $n1 = sprintf '%.0f', uniform_scaling($x_range, $midi_range, $y->[0]);
    my $note = Music::Note->new($n1, 'midinum');
    $n1++ if $note->format('isobase') =~ /[#b]/;
    my $n2 = sprintf '%.0f', uniform_scaling($yz_range, $midi_range, $y->[1]);
    $note = Music::Note->new($n2, 'midinum');
    $n2++ if $note->format('isobase') =~ /[#b]/;
    my $n3 = sprintf '%.0f', uniform_scaling($yz_range, $midi_range, $y->[2]);
    $note = Music::Note->new($n3, 'midinum');
    $n3++ if $note->format('isobase') =~ /[#b]/;
    # say "N: $n1, $n2, $n3";
    $score->n('qn', $n1, $n2, $n3);
}

close $fh;
$score->write_score("$0.mid");
