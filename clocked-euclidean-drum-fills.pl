#!/usr/bin/env perl

# Play and clock an external MIDI device, like a drum machine or sequencer.
# Examples:
#   perl clocked-euclidean-drums-fills.pl fluid 90
#   perl clocked-euclidean-drums-fills.pl usb 100 -1

use v5.36;
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use Math::Prime::XS qw(primes);
use MIDI::RtMidi::FFI::Device ();
use Music::CreatingRhythms ();
use Music::Duration::Partition ();

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120; # beats-per-minute
my $chan = shift // 9; # 0-15, 9=percussion, -1=multi-timbral

my $drums = {
    kick  => { num => 36, chan => $chan < 0 ? 0 : $chan, pat => [] },
    snare => { num => 38, chan => $chan < 0 ? 1 : $chan, pat => [] },
    hihat => { num => 42, chan => $chan < 0 ? 2 : $chan, pat => [] },
    crash => { num => 49, chan => $chan < 0 ? 3 : $chan, pat => [] },
};

my $notes = [qw(60 64 67)]; # used for random assignment below

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my %primes = ( # for computing patterns
    all  => [ primes($beats) ],
    to_5 => [ primes(5) ],
    to_7 => [ primes(7) ],
);
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my $bar_count = 0; # how many measures?
my $toggle = 0; # part A or B?
my $hats = 0; # toggle 1st hihat beat
my $trigger = 0; # trigger a fill
my $filled = 0; # did we just fill?
my @queue; # priority queue for note_on/off messages

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('RtMidiOut');
$midi_out->open_port_by_name(qr/\Q$name/i);

$SIG{INT} = sub { 
    say "\nStop";
    exit;
};

my $mcr = Music::CreatingRhythms->new;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            if (($beat_count + $beats - $trigger) % ($beats * $divisions - 1) == 0) {
                adjust_drums($mcr, $drums, \%primes, \$toggle, 1, \$filled); # fill!
                $filled++;
            }
            if ($beat_count % ($beats * $divisions) == 0) {
                adjust_drums($mcr, $drums, \%primes, \$toggle, 0, \$filled); # normal part
                $trigger++;
            }
            for my $drum (keys %$drums) {
                if ($drums->{$drum}{pat}[ $beat_count % scalar($drums->{$drum}{pat}->@*) ]) {
                    push @queue, { drum => $drum, velocity => velocity(-10, 10, 110) };
                }
            }
            for my $drum (@queue) {
                $midi_out->note_on(
                    $drums->{ $drum->{drum} }{chan},
                    $drums->{ $drum->{drum} }{num},
                    $drum->{velocity}
                );
            }
            $beat_count++;
        }
        else {
            while (my $drum = pop @queue) {
                $midi_out->note_off(
                    $drums->{ $drum->{drum} }{chan},
                    $drums->{ $drum->{drum} }{num},
                    0
                );
            }
        }
        if ($ticks % ($clocks_per_beat * $divisions) == 0) {
            $bar_count++;
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub adjust_cymbals($drums, $filled) {
    if ($$filled) {
        $drums->{crash}{pat}[0] = 1; # crash on one
        $drums->{hihat}{pat}[0] = 0; # mutually exclusive
    }
    else {
        $drums->{crash}{pat}[0] = 0; # not crashing
        $drums->{hihat}{pat}[0] = $hats; # restore hihat bit
    }
    $$filled = 0;
}

sub adjust_drums($mcr, $drums, $primes, $toggle, $fill_flag, $filled) {
    # choose random primes to use by the hihat, kick, and snare
    my ($p, $q, $r) = map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
    if ($fill_flag) {
        say 'fill';
        my $size = rand() < 0.5 ? 2 : 4;
        say "S: $size";
        my %durations = (
            sn => [1],
            en => [1,0],
            qn => [1,0,0,0],
        );
        my $mdp = Music::Duration::Partition->new(
            size    => $divisions,
            pool    => [qw(qn en sn)],
            weights => [1, 2, 1],
            groups  => [0, 0, 2],
        );
        my $motif = $mdp->motif;
        my @converted = map { $durations{$_}->@* } @$motif;
        if ($size < 4) {
            my %pats = part_A($mcr, $drums, $primes, $beats);
            my $div = $beats / $size;
            $drums->{hihat}{pat} = [ $pats{hihat}->@[0 .. $div - 1], (0) x $div ];
            $drums->{kick}{pat}  = [ $pats{kick}->@[0 .. $div - 1], (0) x $div ];
            $drums->{snare}{pat} = [ $pats{snare}->@[0 .. $div - 1], @converted[0 .. $div - 1] ]
            # say ddc $drums;
        }
        else {
            $drums->{hihat}{pat} = [ (0) x $beats ];
            $drums->{kick}{pat}  = [ (0) x $beats ];
            $drums->{snare}{pat} = \@converted;
        }
    }
    elsif ($$toggle == 0) {
        my %pats = part_A($mcr, $drums, $primes, $beats);
        $drums->{hihat}{pat} = $pats{hihat};
        $drums->{kick}{pat}  = $pats{kick};
        $drums->{snare}{pat} = $pats{snare};
        $$toggle = 1; # set to part B
    }
    elsif ($$toggle == 1) {
        my %pats = part_B($mcr, $drums, $primes, $beats);
        $drums->{hihat}{pat} = $pats{hihat};
        $drums->{kick}{pat}  = $pats{kick};
        $drums->{snare}{pat} = $pats{snare};
        $$toggle = 0; # set to part A
    }
    $hats = $drums->{hihat}{pat}[0]; # save bit
    $drums->{crash}{pat} = [ (0) x ($beats * $divisions) ];
    adjust_cymbals($drums, $filled);
    $drums->{crash}{num} = random_note($notes);
    $drums->{snare}{num} = random_note($notes);
    $drums->{kick}{num}  = random_note($notes);
    $drums->{hihat}{num} = random_note($notes);
}

sub part_A($mcr, $drums, $primes, $beats) {
    say 'part A';
    # choose random primes to use by the hihat, kick, and snare
    my ($p, $q, $r) = primes_list($primes);
    my %patterns = (
        hihat => $mcr->euclid($p, $beats),
        kick  => $mcr->euclid($q, $beats),
        snare => $mcr->rotate_n($r, $mcr->euclid(2, $beats)),
    );
    return %patterns;
}

sub part_B($mcr, $drums, $primes, $beats) {
    say 'part B';
    # choose a random prime to use by the hihat
    my ($p) = primes_list($primes);
    my %patterns = (
        hihat => $mcr->euclid($p, $beats),
        kick  => [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1)],
        snare => [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 1 0)],
    );
    return %patterns;
}

sub primes_list($primes) {
    return map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

sub random_note($notes) {
    my $random = $notes->[ int rand @$notes ] - 24;
    return $random;
}