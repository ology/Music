#!/usr/bin/env perl

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();

my $port = shift || 'MIDIThing'; # MIDI device
my $bpm  = shift || 70; # beats-per-minute

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my @queue; # priority queue for note_on/off messages

my @notes = (32, 48, 60);

my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # this will die on windows
catch ($e) {}
try { $midi_out->open_port_by_name(qr/\Q$port/i) }
catch ($e) { die "Can't open MIDI port: $port\n" }
say "Sending MIDI to $port";

$SIG{INT} = sub { 
    say "\nStop";
    try {
        $midi_out->stop;
        $midi_out->panic;
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n";
    }
    exit;
};

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $clocks_per_beat == 0) {
            push @queue, $notes[int rand @notes];
            for my $note (@queue) {
                $midi_out->note_on(
                    0,
                    $note,
                    127
                );
            }
            $beat_count++;
        }
        else {
            while (my $note = pop @queue) {
                $midi_out->note_off(
                    0,
                    $note,
                    0
                );
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;
