#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-voice.pl --port=usb --bpm=111 --scale=major --octave=2

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use Music::Scales qw(get_scale_MIDI);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::Util qw(dura_size);
use Music::Duration::Partition ();
use Music::VoiceGen ();
use Getopt::Long qw(GetOptions);
no warnings 'experimental::try';

my %opt = (
    port   => 'MIDIThing2',
    bpm    => 70,
    scale  => 'pminor',
    octave => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'scale=s',
    'octave=i',
);

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my @queue; # priority queue for note_on/off messages
my $i; # queue index
my $n; # selected note
my @onsets;

my $mdp = Music::Duration::Partition->new(
    size    => $divisions,
    pool    => [qw(hn dqn qn en sn)],
    weights => [1, 2, 2, 1, 3],
    groups  => [0, 0, 0, 2, 2],
);
my @motifs = $mdp->motifs(5);
my @pitches = (
  get_scale_MIDI('C', $opt{octave}, $opt{scale}),
  get_scale_MIDI('C', $opt{octave} + 1, $opt{scale}),
);
my @intervals = qw(-3 -2 -1 1 2 3);
my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => \@intervals,
);

# open the midi device for output
my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
catch ($e) { warn 'Not a Mac' }
try { $midi_out->open_port_by_name(qr/\Q$opt{port}/i) }
catch ($e) { die "Can't open MIDI port: $opt{port}\n" }
say "Sending MIDI to $opt{port} at $opt{bpm} BPM\n";

$midi_out->start; # start the sequencer

# redefine what happens on ^C
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
        if ($ticks % $sixteenth == 0) {
            if ($beat_count % ($divisions * $divisions) == 0) { # do this every measure:
                # populate the queue
                my $motif = $motifs[int rand @motifs]; # TODO something clever?
                say "$beat_count => ", ddc $motif;
                @queue = map { +{ pitch => $voice->rand, duration => $_ } } @$motif;
                say 'Queue: ', ddc \@queue;
                # compute the onsets
                my $tally = 0;
                @onsets = ($tally);
                for my $note (@queue[0 .. $#queue - 1]) {
                    $tally += dura_size($note->{duration}) * $divisions;
                    push @onsets, $tally;
                }
                @onsets = map { $beat_count + $_ } @onsets;
                say 'Onset: ', ddc \@onsets;
                $i = 0; # reset the queue index
            }
            # say "* $i, $beat_count, ", (defined $onsets[$i] ? $onsets[$i] : '?');
            # if we are on a beat onset, note_on!
            if (defined $onsets[$i] && $onsets[$i] == $beat_count) {
                $n = $queue[$i];
                say "$i, $beat_count, ", ddc $n;
                $midi_out->note_on(
                    0,  # channel
                    $n->{pitch},
                    127 # velocity
                );
                $i++; # increment the queue index
            }
            $beat_count++;
        }
        else {
            # if we just played a note, close it
            if ($n) {
                $midi_out->note_off(
                    0,
                    $n->{pitch},
                    0
                );
                $n = undef;
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;
