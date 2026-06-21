#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-together.pl --port=usb --bpm=111 --scale=major --octave=2

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
    base   => 'C',
    scale1 => 'pminor',
    scale2 => 'minor',
    octave => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'base=s',
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
my @queue2; # priority queue for note_on/off messages
my $i2; # queue index
my $n2; # selected note
my @onsets2;

my $mdp = Music::Duration::Partition->new(
    size    => $divisions,
    pool    => [qw(hn dqn qn)],
    weights => [   1, 2,  2 ],
    groups  => [   0, 0,  0 ],
);
my @motifs = $mdp->motifs(5);
my @pitches = (
  get_scale_MIDI($opt{'base'}, $opt{octave}, $opt{scale}),
  get_scale_MIDI($opt{'base'}, $opt{octave} + 1, $opt{scale}),
);
my @intervals = qw(-3 -2 -1 1 2 3);
my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => \@intervals,
);

my $mdp2 = Music::Duration::Partition->new(
    size    => $divisions,
    pool    => [qw(dqn qn en sn)],
    weights => [   2,  2, 1, 1 ],
    groups  => [   0,  0, 2, 2 ],
);
my @motifs2 = $mdp2->motifs(5);
my @pitches2 = (
  get_scale_MIDI($opt{'base'}, $opt{octave}, $opt{scale2}),
  get_scale_MIDI($opt{'base'}, $opt{octave} + 1, $opt{scale2}),
);
my @intervals2 = qw(-3 -2 -1 1 2 3);
my $voice2 = Music::VoiceGen->new(
    pitches   => \@pitches2,
    intervals => \@intervals2,
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
                populate(\@motifs, $beat_count, \@queue, $voice, \@onsets, \$i);
                # populate(\@motifs2, $beat_count, \@queue2, $voice2, \@onsets2, \$i2);
            }
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
            if (defined $onsets2[$i2] && $onsets2[$i2] == $beat_count) {
                $n2 = $queue2[$i2];
                say "2: $i2, $beat_count, ", ddc $n2;
                $midi_out->note_on(
                    1,  # channel
                    $n2->{pitch},
                    127 # velocity
                );
                $i2++; # increment the queue index
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
            if ($n2) {
                $midi_out->note_off(
                    1,
                    $n2->{pitch},
                    0
                );
                $n2 = undef;
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub populate ($ms, $count, $q, $v, $ons, $inc) {
    my $motif = $ms->[int rand @$ms]; # TODO something clever?
    say "$count => ", ddc $motif;
    @$q = map { +{ pitch => $v->rand, duration => $_ } } @$motif;
    say 'Queue: ', ddc $q;
    # compute the onsets
    my $tally = 0;
    @$ons = ($tally);
    for my $note ($q->@[0 .. $#$q - 1]) {
        $tally += dura_size($note->{duration}) * $divisions;
        push @$ons, $tally;
    }
    @$ons = map { $count + $_ } @$ons;
    say 'Onset: ', ddc $ons;
    $$inc = 0; # reset the queue index
};