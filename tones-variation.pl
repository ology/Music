#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-variation.pl --verbose=1 --scales='pminor minor' --octaves='2 4' --patches='35 70' --port=fluid --bpm=60

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::Util qw(dura_size);
use Getopt::Long qw(GetOptions);
use Music::VoicePhrase ();
no warnings 'experimental::try';

my %opt = (
    port    => 'MIDIThing2',
    bpm     => 70,
    base    => 'C',
    scales  => 'pminor minor',
    octaves => '0, 1',
    patches => '35 5',
    verbose => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'scales=s',
    'octaves=s',
    'patches=s',
    'verbose=s',
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
my $patches = [ split /\s+/, $opt{patches} ];

# TODO prompt for part args
my @parts = (
    Music::VoicePhrase->new(
        channel   => 0,
        size      => $divisions,
        pool      => [qw(dhn hn qn)],
        weights   => [   1,  2, 2 ],
        groups    => [   0,  0, 0 ],
        motif_num => 4,
        intervals => [(-7 .. -1),(1 .. 7)],
        scale     => $scales->[0],
        octave    => $octaves->[0],
        verbose   => $opt{verbose},
    ),
    Music::VoicePhrase->new(
        channel   => 1,
        size      => $divisions,
        pool      => [qw(dqn qn en sn)],
        weights   => [   2,  2, 1, 1 ],
        groups    => [   0,  0, 2, 2 ],
        motif_num => 4,
        scale     => $scales->[1],
        octave    => $octaves->[1],
        verbose   => $opt{verbose},
    ),
    Music::VoicePhrase->new(
        channel   => 1,
        size      => $divisions,
        pool      => [qw(dqn qn)],
        weights   => [   1,  1 ],
        groups    => [   0,  0 ],
        motif_num => 4,
        scale     => $scales->[1],
        octave    => $octaves->[1],
        verbose   => $opt{verbose},
    ),
);
my @play;

# open the midi device for output
my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
catch ($e) { warn 'Not a Mac' if $opt{verbose} }
try { $midi_out->open_port_by_name(qr/\Q$opt{port}/i) }
catch ($e) { die "Can't open MIDI port: $opt{port}\n" }
say "Sending MIDI to $opt{port} at $opt{bpm} BPM\n" if $opt{verbose};

$midi_out->start; # start the sequencer

$midi_out->program_change(0, $patches->[0]) if defined $patches->[0];
$midi_out->program_change(1, $patches->[1]) if defined $patches->[1];

# redefine what happens on ^C
$SIG{INT} = sub { 
    say "\nStop" if $opt{verbose};
    try {
        $midi_out->stop;
        $midi_out->panic;
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n" if $opt{verbose};
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
            if ($beat_count > 0 && $beat_count % ($divisions ** 3) == 0) { # do this every 4th measure:
                say "***** ALT! *****\n\n" if $opt{verbose};
                @play = @parts[0,2];
                populate($_, $beat_count) for @play;
            }
            elsif ($beat_count % ($divisions * $divisions) == 0) { # do this every measure:
                @play = @parts[0,1];
                populate($_, $beat_count) for @play;
            }
            for my $part (@play) {
                on($part, $beat_count);
                off($part, $beat_count);
            }
            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub populate ($p, $count) {
    my $motif = $p->motifs->[int rand $p->motifs->@*]; # TODO something clever?
    say "$count => ", ddc $motif if $opt{verbose};
    $p->queue([
        map {
            +{
                pitch    => $p->voice->rand,
                duration => $_,
                velocity => velocity(-10, 10, 110),
            }
        } @$motif
    ]);
    # compute the onsets
    my $tally = 0;
    my @ons = ($tally);
    for my $note ($p->queue->@[0 .. $p->queue->@* - 1]) {
        my $on = dura_size($note->{duration}) * $divisions;
        $tally += $on;
        push @ons, $tally;
        $note->{on}  = $count + $tally - $on;
        $note->{off} = $count + $tally;
    }
    $p->onsets([ map { $count + $_ } @ons ]);
    say 'Onsets: ', ddc $p->onsets if $opt{verbose};
    say 'Queue: ', ddc $p->queue if $opt{verbose};
    $p->index(0); # reset the queue index
};

sub on ($p, $count) {
    # if we are on a beat onset, note_on!
    if (defined $p->onsets->[$p->index] && $p->onsets->[$p->index] == $count) {
        my $n = $p->queue->[$p->index];
        say 'ON: ', $p->{channel}, ', ', $p->index, ", $count, ", ddc $n if $opt{verbose};
        if ($n) {
            $midi_out->note_on(
                $p->{channel},
                $n->{pitch},
                $n->{velocity},
            );
        }
        else {
            warn "WARNING: No note to play?\n\n";
        }
        $p->increment_index;
    }
}

sub off ($p, $count) {
    for my $n (grep { $count == $_->{off} } $p->queue->@*) {
        say 'OFF: ', $p->{channel}, ", $count, ", ddc $n if $opt{verbose};
        $midi_out->note_off(
            $p->{channel},
            $n->{pitch},
            0
        );
    }
}

sub velocity ($min, $max, $offset) {
    return $offset + int(rand($max - $min + 1)) + $min;
}