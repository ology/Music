#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-oo.pl --port=usb --bpm=111 --scales='pentatonic major' --octaves='0 1'

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
use Music::VoicePhrase ();
no warnings 'experimental::try';

my %opt = (
    port    => 'MIDIThing2',
    bpm     => 70,
    base    => 'C',
    scales  => 'pminor minor',
    octaves => '0, 1',
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'scales=s',
    'octaves=s',
);

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $scales  = [ split /\s+/, $opt{scales} ];
my $octaves = [ split /\s+/, $opt{octaves} ];

my $mvp = Music::VoicePhrase->new(
    size      => $divisions,
    pool      => [qw(dhn hn qn)],
    weights   => [   1, 2,  2 ],
    groups    => [   0, 0,  0 ],
    motif_num => 4,
    scale     => $scales[0],
);

my $mvp2 = Music::VoicePhrase->new(
    size      => $divisions,
    pool      => [qw(dqn qn en sn)],
    weights   => [   2,  2, 1, 1 ],
    groups    => [   0,  0, 2, 2 ],
    motif_num => 4,
    scale     => $scales[1],
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
                populate ($mvp, $beat_count);
                populate ($mvp2, $beat_count);
            }
            
            # if we are on a beat onset, note_on!
            on($mvp, $beat_count, 0);
            on($mvp2, $beat_count, 1);

            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub populate ($m, $count) {
    my $motif = $m->motifs->[int rand $m->motifs->@*]; # TODO something clever?
    say "$count => ", ddc $motif;
    $m->queue([ map { +{ pitch => $m->voice->rand, duration => $_ } } @$motif ]);
    say 'Queue: ', ddc $m->queue;
    # compute the onsets
    my $tally = 0;
    my @ons = ($tally);
    for my $note ($m->queue->@[0 .. $m->queue->@* - 1]) {
        $tally += dura_size($note->{duration}) * $divisions;
        push @ons, $tally;
    }
    $m->onsets([ map { $count + $_ } @ons ]);
    say 'Onset: ', ddc $m->onsets;
    $m->index(0); # reset the queue index
};

sub on ($m, $count, $chan) {
    my $selected;
    if (defined $m->onsets->[$m->index] && $m->onsets->[$m->index] == $count) {
        $selected = $m->queue->[$m->index];
        say $m->index, ', ', "$count, ", ddc $selected;
        $midi_out->note_on(
            $chan,  # channel
            $selected->{pitch},
            127 # velocity
        );
        $m->increment_index;
    }
    return $selected;
}
