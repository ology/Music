#!/usr/bin/env perl

# Play and clock an external MIDI device, like a drum machine or sequencer.
# Example: perl clocked-euclidean-drums.pl usb 90

use v5.36;
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use Math::Prime::XS qw(primes);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(dura_size);
use Music::CreatingRhythms ();
use Music::Duration::Partition ();
use Time::HiRes qw(sleep);

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120;

my $drums = {
    kick  => { num => 36, chan => 0 },
    snare => { num => 38, chan => 1 },
    hihat => { num => 42, chan => 2 },
    crash => { num => 49, chan => 3 },
    # ride  => { num => 51, chan => 4 },
    # tom   => { num => 45, chan => 5 },
};
my $notes = [qw(60 64 67)];

my $divisions = 4;
my $clocks_per_beat = 24;
my $per_sec = 60 / $bpm;
my $clock_interval = $per_sec / $clocks_per_beat; # seconds / bpm / ppqn
my $beats = 16; # beats in a phrase
my $sixteenth = $clocks_per_beat / $divisions; # 16th-notes
my $beat_interval = $per_sec / $divisions; # 16th-note resolution
my @all_primes = primes($beats);
my @to_5_primes = primes(5);
my @to_7_primes = primes(7);
my $ticks = 0; # clock ticks
my $beat_count = 0;
my $toggle = 0; # part A or B?
my $filled = 0; # did we just fill?
my $hats = 0; # toggle 1st hihat beat
my @queue;

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
            if ($beat_count % ($divisions - 1) == 0) {
                adjust_drums($drums, \@all_primes, \@to_5_primes, \@to_7_primes, \$toggle);
            }
            for my $drum (keys %$drums) {
                if ($drums->{$drum}{pat}[ $beat_count % $beats ]) {
                    push @queue, { drum => $drum, velocity => 127 };
                }
            }
            for my $drum (@queue) {
                midi_msg($midi_out, 'note_on', $drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, $drum->{velocity});
            }
            $beat_count++;
        }
        else {
            while (my $drum = pop @queue) {
                midi_msg($midi_out, 'note_off', $drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, 0);
            }
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub part($midi_out, $drums, $beats, $size) {
    my $end = $size == 2 ? $beats / 2 : $beats;
    for my $i (0 .. $end - 1) {
        my %simul = map { $_ => $drums->{$_}{pat}[$i] } keys %$drums;
        play_simul($midi_out, $beat_interval, $drums, \%simul);
    }
}

sub fill($midi_out, $size) {
    my $mdp = Music::Duration::Partition->new(
        size    => $size,
        pool    => [qw(qn en sn)],
        weights => [1, 2, 1],
        groups  => [0, 0, 2],
    );
    my $motif = $mdp->motif;
    for my $duration (@$motif) {
        midi_msg($midi_out, 'note_on', $drums->{snare}{chan}, $drums->{snare}{num}, velocity(-10, 10, 64));
        # sleep(dura_size($duration) * $per_sec * 0.9);
        # midi_msg($midi_out, 'note_off', $drums->{snare}{chan}, $drums->{snare}{num}, 0);
        # sleep(dura_size($duration) * $per_sec * 0.1);
    }
}

sub play_simul($midi_out, $beat_interval, $drums, $simul) {
    my $i = 0;
    for my $drum (keys %$simul) {
        if ($simul->{$drum} == 1) {
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 127);
        }
        else { # rest
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
        }
    }
    # sleep($beat_interval * 0.9);
    # $i = 0;
    # for my $drum (keys %$simul) {
    #     $midi_out->send_event('note_off', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
    # }
    # sleep($beat_interval * 0.1);
}

sub adjust_cymbal($drums, $filled) {
    if ($$filled) {
        $drums->{crash}{pat}[0] = 1;
        $drums->{hihat}{pat}[0] = 0;
    }
    else {
        $drums->{crash}{pat}[0] = 0;
        $drums->{hihat}{pat}[0] = $hats; # restore bit
    }
    $$filled = 0;
}

sub adjust_drums($drums, $all_primes, $to_5_primes, $to_7_primes, $toggle) {
    my $p = $all_primes->[ int rand @$all_primes ];
    my $q = $to_5_primes->[ int rand @$to_5_primes ];
    my $r = $to_7_primes->[ int rand @$to_7_primes ];
    if ($$toggle == 0) { # part A
        $drums->{kick}{pat}  = $mcr->euclid($q, $beats);
        $drums->{snare}{pat} = $mcr->rotate_n($r, $mcr->euclid(2, $beats));
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 1;
    }
    else { # part B
        $drums->{kick}{pat}  = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1];
        $drums->{snare}{pat} = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0];
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 0;
    }
    $hats = $drums->{hihat}{pat}[0]; # save bit
    $drums->{crash}{pat} = [ (0) x $beats ];
    $drums->{crash}{num} = random_note($notes);
    $drums->{snare}{num} = random_note($notes);
    $drums->{kick}{num}  = random_note($notes);
    $drums->{hihat}{num} = random_note($notes);
}

sub midi_msg($midi_out, $event, $channel, $note, $velocity) {
    $midi_out->send_event($event, $channel, $note, $velocity);
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

sub random_note($notes) {
    my $random = $notes->[ int rand @$notes ] - 24;
    return $random;
}