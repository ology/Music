#!/usr/bin/env perl

# Play and clock a MIDI drum machine in 16-beat sequences.
# Examples:
#   perl clocked-euclidean-drums.pl fluid 120 # with fluidsynth
#   perl clocked-euclidean-drums.pl usb 90 -1 # multi-timbral

use v5.36;
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use Math::Prime::XS qw(primes);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(dura_size);
use Music::CreatingRhythms ();
use Music::Duration::Partition ();

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120; # beats-per-minute
my $chan = shift // 9; # 0-15, 9=percussion, -1=multi-timbral

my $drums = {
    kick  => { num => 36, chan => $chan < 0 ? 0 : $chan, pat => [] },
    snare => { num => 38, chan => $chan < 0 ? 1 : $chan, pat => [] },
    hihat => { num => 42, chan => $chan < 0 ? 2 : $chan, pat => [] },
};

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # seconds / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my %primes = ( # for computing the pattern
    all  => [ primes($beats) ],
    to_5 => [ primes(5) ],
    to_7 => [ primes(7) ],
);
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my $toggle = 0; # part A or B?
my $hats = 0; # toggle 1st hihat beat
my @queue; # priority queue for note_on/off messages

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('RtMidiOut');
$midi_out->open_port_by_name(qr/\Q$name/i);

$SIG{INT} = sub { # halt gracefully
    say "\nStop";
    exit;
};

# for computing the pattern
my $mcr = Music::CreatingRhythms->new;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            if ($beat_count % ($divisions - 1) == 0) {
                adjust_drums($mcr, $drums, \%primes, \$toggle);
            }
            for my $drum (keys %$drums) {
                if ($drums->{$drum}{pat}[ $beat_count % $beats ]) {
                    push @queue, { drum => $drum, velocity => 127 };
                }
            }
            for my $drum (@queue) {
                $midi_out->note_on($drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, $drum->{velocity});
            }
            $beat_count++;
        }
        else {
            while (my $drum = pop @queue) {
                $midi_out->note_off($drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, 0);
            }
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub adjust_drums($mcr, $drums, $primes, $toggle) {
    # choose random primes to use by the kick, snare, and hihat
    my ($p, $q, $r) = map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
    if ($$toggle == 0) { # part A
        $drums->{kick}{pat}  = $mcr->euclid($q, $beats);
        $drums->{snare}{pat} = $mcr->rotate_n($r, $mcr->euclid(2, $beats));
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 1; # set to part B
    }
    else { # part B
        $drums->{kick}{pat}  = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1];
        $drums->{snare}{pat} = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0];
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 0; # set to part A
    }
    $hats = $drums->{hihat}{pat}[0]; # save bit
}