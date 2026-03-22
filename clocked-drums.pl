#!/usr/bin/env perl

# Clock an external MIDI device, like a drum machine or sequencer.
# Example: perl clock-gen-async.pl usb 90

use v5.36;
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::RtMidi::FFI::Device ();
use Music::CreatingRhythms ();
use Time::HiRes qw(sleep);

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120;

my $clocks_per_beat = 24;
my $clock_interval = 60 / $bpm / $clocks_per_beat; # seconds / bpm / ppqn
my $beat_interval = 60 / $bpm / 4; # 16th-note resolution
my $ticks = 0;

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('RtMidiOut');
$midi_out->open_port_by_name(qr/\Q$name/i);

$SIG{INT} = sub { 
    say "\nStop";
    exit;
};

my $drums = {
    kick    => { num => 36, chan => 0 },
    snare   => { num => 38, chan => 1 },
    hihat   => { num => 42, chan => 2 },
    # cymbals => { num => 49, chan => 3 },
};
my $mcr = Music::CreatingRhythms->new;
my $beats = 16;
my $patterns = {
    kick    => $mcr->euclid(2, $beats),
    snare   => $mcr->rotate_n(4, $mcr->euclid(2, $beats)),
    hihat   => $mcr->euclid(11, $beats),
    # cymbals => [ 0 .. $beats - 1 ],
};

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $clocks_per_beat == 0) {
            for my $i (0 .. $beats - 1) {
                my $simul = {
                    kick  => $patterns->{kick}[$i],
                    snare => $patterns->{snare}[$i],
                    hihat => $patterns->{hihat}[$i],
                };
                play_simul($midi_out, $beat_interval, $drums, $simul);
            }
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub play_simul($midi_out, $beat_interval, $drums, $simul) {
    my $i = 0;
    for my $drum (keys %$simul) {
        my $bit = $simul->{$drum};
        if ($bit == 1) {
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 127);
        }
        else { # rest
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
        }
    }
    sleep($beat_interval * 0.9);
    $i = 0;
    for my $drum (keys %$simul) {
        $midi_out->send_event('note_off', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
    }
    sleep($beat_interval * 0.1);
}