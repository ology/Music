#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-rhythm.pl usb 70

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use Music::Scales qw(get_scale_MIDI);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::Util qw(dura_size);
use Music::Duration::Partition ();
use Time::HiRes qw(sleep); # TODO no sleeping!
no warnings 'experimental::try';

my $port = shift || 'MIDIThing2'; # MIDI device
my $bpm  = shift || 70; # beats-per-minute

# choose the pitches to use
my @notes = (
  get_scale_MIDI('C', 0, 'pminor'),
  get_scale_MIDI('C', 1, 'pminor'),
);

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my @queue; # priority queue for note_on/off messages

my $mdp = Music::Duration::Partition->new(
    size    => 4,
    pool    => [qw(wn dhn hn dqn qn)],
    # weights => [1, 2, 1],
    # groups  => [0, 0, 2],
);
my @motifs = $mdp->motifs(4);

# open the midi device for output
my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
catch ($e) { warn 'Not a Mac' }
try { $midi_out->open_port_by_name(qr/\Q$port/i) }
catch ($e) { die "Can't open MIDI port: $port\n" }
say "Sending MIDI to $port at $bpm BPM";
$midi_out->start;

# redefine what happens on halt
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
            if ($beat_count % 4 == 0) {
                my $motif = $motifs[ int rand @motifs ]; # TODO something better
                say "$beat_count => ", ddc $motif;
                @queue = ();
                for my $duration (@$motif) {
                    my $note = $notes[int rand @notes];
                    push @queue, { pitch => $note, duration => $duration };
                }
            }
            # note_on!
            for my $note (@queue) {
                $midi_out->note_on(
                    0,  # channel
                    $note->{pitch},
                    127 # velocity
                );
                sleep(dura_size($note->{duration}) * 0.9); # TODO no sleeping!
            }
            $beat_count++;
        }
        else {
            # drain the queue and send note_off msgs
            while (my $note = pop @queue) {
                $midi_out->note_off(
                    0,
                    $note->{pitch},
                    0
                );
                sleep(dura_size($note->{duration}) * 0.1); # TODO no sleeping!
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;
