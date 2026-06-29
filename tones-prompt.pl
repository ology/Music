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
use MIDI::Util qw(dura_size scale_names);
use Getopt::Long qw(GetOptions);
use Music::VoicePhrase ();
use Term::Choose qw(choose);
use IO::Prompt::Tiny qw/prompt/;
no warnings 'experimental::try';

use constant QUIT => 'Quit';

my %opt = (
    port    => 'MIDIThing2',
    bpm     => 70,
    base    => 'C',
    verbose => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'verbose=s',
);

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my @parts;
my %choices = (
    intervals => {
        '-7..-1,1..7' => [(-7 .. -1),(1 .. 7)],
        '-3..-1,1..3' => [(-3 .. -1),(1 .. 3)],
    },
);

my $response = '';
while ($response ne 'd') {
    push @parts, Music::VoicePhrase->new(
        channel   => make_choice([0 .. 15], 'channel', 1),
        motif_num => make_choice([1 .. 16], 'motif_num', 4),
        scale     => make_choice(scale_names(), 'scale', 2),
        octave    => make_choice([0 .. 9], 'octave', 1),
        size      => make_choice([qw(1 2 2.5 3 3.5), (4 .. 16)], 'size', 6)
        pool      => make_choice($choices{pool}, 'pool', 1),
        weights   => make_choice($choices{weights}, 'weights', 1),
        groups    => make_choice($choices{groups}, 'groups', 1),
        pitches   => make_choice($choices{pitches}, 'pitches', 1),
        intervals => make_choice($choices{intervals}, 'intervals', 1),
    );
    my $response = prompt('a = another; d = done', 'a');
    # if ($response eq 'd') {
    #     last;
    # }
}

sub make_choice ($choices, $name, $default) {
    my @args;
    if (ref $choices eq 'ARRAY') {
        @args = (QUIT, @$choices);
    }
    else { # hashref
        @args = (QUIT, (sort keys %$choices), 'custom');
    }
    my $choice = choose(\@args, {
        prompt  => "Choose a $name:",
        default => $default,
    });
    if ($choice eq 'custom') {
        # TODO
    }
    exit if $choice eq QUIT;
    return $choice;
}

__END__
my @parts = (
    Music::VoicePhrase->new(
        channel   => 0,
        size      => $divisions,
        pool      => [qw(dhn hn qn)],
        weights   => [   1,  2, 2 ],
        groups    => [   0,  0, 0 ],
        motif_num => 4,
        pitches   => $pitches,
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
        pitches   => $pitches,
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
        pitches   => $pitches,
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
        for my $chan (0, 1) {
            for my $n (0 .. 127) {
                $midi_out->note_off($chan, $n, 0);
            }
        }
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