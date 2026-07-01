#!/usr/bin/env perl

# Play tonal MIDI in real-time!
# Example(s):
# perl tones-prompt.pl --verbose=1 --port=fluid --bpm=60

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use MIDI::Util qw(dura_size scale_names);
use Music::Scales qw(get_scale_MIDI);
use Music::VoicePhrase ();
use Term::Choose qw(choose);
use IO::Prompt::Tiny qw(prompt);
use Getopt::Long qw(GetOptions);
no warnings 'experimental::try';

use constant QUIT => 'Quit';
use constant DONE => 'Done';

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
my %params;
my %choices = (
    weights => {},
    groups  => {},
    pool    => {
        'wn hn'        => [qw(wn hn)],
        'wn dhn hn qn' => [qw(wn dhn hn qn)],
        'qn en'        => [qw(qn en)],
        'hn dqn qn en' => [qw(hn dqn qn en)],
        'qn den en sn' => [qw(qn den en sn)],
    },
    pitches => {
        '1 octave'  => sub { get_scale_MIDI($opt{'base'}, $params{octave}, $params{scale}) },
        '2 octaves' => sub {
            get_scale_MIDI($opt{'base'}, $params{octave}, $params{scale}),
            get_scale_MIDI($opt{'base'}, $params{octave} + 1, $params{scale}),
        },
    },
    intervals => {
        '-3..-1,1..3' => [(-3 .. -1),(1 .. 3)],
        '-4..-1,1..4' => [(-4 .. -1),(1 .. 4)],
        '-5..-1,1..5' => [(-5 .. -1),(1 .. 5)],
        '-7..-1,1..7' => [(-7 .. -1),(1 .. 7)],
    },
);

my $response = '';
my $i = 0;
while ($response ne DONE || $response ne QUIT) {
    $i++;
    $params{channel}   = make_choice($i, [0 .. 15], 'channel', $i, \%params);
    $params{patch}     = make_choice($i, [0 .. 127], 'patch', 1, \%params);
    $params{motif_num} = make_choice($i, [1 .. 16], 'motif_num', 4, \%params);
    $params{scale}     = make_choice($i, scale_names(), 'scale', 2, \%params);
    $params{octave}    = make_choice($i, [0 .. 9], 'octave', 1, \%params);
    $params{size}      = make_choice($i, [qw(1 2 2.5 3 3.5), (4 .. 16)], 'size', 6, \%params);
    $params{pool}      = make_choice($i, \%choices, 'pool', 1, \%params); # must come before weights & groups
    $params{weights}   = make_choice($i, \%choices, 'weights', 1, \%params);
    $params{groups}    = make_choice($i, \%choices, 'groups', 1, \%params);
    $params{pitches}   = make_choice($i, \%choices, 'pitches', 1, \%params);
    $params{intervals} = make_choice($i, \%choices, 'intervals', 1, \%params);
    push @parts, Music::VoicePhrase->new(%params);
    my $response = choose([QUIT, DONE, 'Another'], {
        prompt  => "Choose:",
        default => 1,
    });
    if ($response eq QUIT) {
        exit;
    }
    elsif ($response eq DONE) {
        last;
    }
}

my @play;

# open the midi device for output
my $midi_out = RtMidiOut->new;
try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
catch ($e) { warn 'Not a Mac' if $opt{verbose} }
try { $midi_out->open_port_by_name(qr/\Q$opt{port}/i) }
catch ($e) { die "Can't open MIDI port: $opt{port}\n" }
say "Sending MIDI to $opt{port} at $opt{bpm} BPM\n" if $opt{verbose};

$midi_out->start; # start the sequencer

for my $part (@parts) {
    $midi_out->program_change($part->{channel}, $part->{patch})
        if defined $part->{patch};
}

# redefine what happens on ^C
$SIG{INT} = sub { 
    say "\nStop" if $opt{verbose};
    try {
        $midi_out->stop;
        $midi_out->panic;
        for my $chan (0 .. 15) {
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
                @play = @parts[-1];
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

sub make_choice ($n, $choices, $name, $default, $params) {
    my @args;
    if (ref $choices eq 'ARRAY') {
        @args = (QUIT, @$choices);
    }
    else { # hashref
        @args = (QUIT, (sort keys $choices->{$name}->%*), 'custom');
    }
    my $choice;
    if ($name eq 'weights' || $name eq 'groups') {
        my $response = prompt(
            "Part $n - Choose the $name for pool = " . join(' ', $params->{pool}->@*) . ':',
            join(' ', map { 0 } $params->{pool}->@*)
        );
        $choice = [ split /\s+/, $response ];
    }
    else {
        $choice = choose(\@args, {
            prompt  => "Part $n - Choose the $name:",
            default => $default,
        });
        if (ref $choices eq 'HASH') {
            $choice = $name eq 'pitches'
                ? [ $choices->{$name}{$choice}->() ]
                : $choices->{$name}{$choice};
        }
        if ($choice eq 'custom') {
            my $response = prompt('Enter a space-separated list: ');
            $choice = [ split /\s+/, $response ];
        }
    }
    say ddc $params if $opt{verbose};
    exit if $choice eq QUIT;
    return $choice;
}
