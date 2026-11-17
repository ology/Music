#!/usr/bin/env perl

# Play a generative sequence that jumps by musical interval.

# Examples:
# perl interval-hop.pl --verbose --port=synth

use v5.40;
use Data::Dumper::Compact qw(ddc);               # debugging
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use Music::Scales qw(get_scale_MIDI);            # pitches
use Music::VoiceGen ();                          # voices!

my %opt = (
    port     => undef,       # required MIDI device name fragment
    bpm      => 70,          # beats-per-minute
    channel  => 0,           # midi channel
    octave   => 4,           # 0 .. 9
    scale    => 'minor',     # scale name
    tonic    => 'C',         # scale key base note
    pitches  => 3,           # number of octaves
    jumps    => '-3,-2,2,3', # allowed interval jumps
    verbose  => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'channel=i',
    'octave=i',
    'scale=s',
    'tonic=s',
    'jumps=s',
    'verbose',
);

die "Open MIDI port name required for 'port'\n" unless $opt{port};

# we are in 4/4 time...
my $divisions       = 4; # divisions of a quarter-note into 16ths
my $beats           = $divisions * $divisions; # beats in a phrase
my $clocks_per_beat = 6 * $divisions; # PPQN
my $clock_interval  = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn

my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start }

my $ticks      = 0; # clock ticks
my $beat_count = 0; # beats!

my @pitches = map { get_scale_MIDI($opt{tonic}, $opt{octave}, $opt{scale}) } 1 .. $opt{pitches};
my @jumps = split /,/, $opt{jumps};
my $voice = Music::VoiceGen->new(
    pitches   => \@pitches,
    intervals => \@jumps,
);

# open the midi devices for output
my $midi_out = out_port($opt{port});
$midi_out->start;
say "Started '$opt{port}' for MIDI output" if $opt{verbose};

my $loop = IO::Async::Loop->new;

# Graceful ^C:
$loop->watch_signal(INT => sub {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    $loop->stop;
});

my $timer = IO::Async::Timer::Periodic->new(
    interval   => $clock_interval,
    reschedule => 'hard', # anchor to a fixed schedule, don't let tempo drift
    on_tick    => sub {
        $midi_out->clock;
        $ticks++;

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($opt{channel}, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending arp notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($opt{channel}, $p->{note}, velocity(-10, 10, 110));
            push @active, { note => $p->{note}, off_tick => $p->{off_tick} };
        }

        # TODO explain this modulo
        if (($ticks - 1) % $clocks_per_beat == 0) {
            trigger_notes();
            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub trigger_notes {
    my @notes = map { $voice->rand } 1 .. $divisions;
    my $on_tick = $ticks;
    my $step_ticks = 1;
    for my $n (@notes) {
        push @pending, {
            note     => $n,
            on_tick  => $on_tick,
            off_tick => $on_tick + $step_ticks,
        };
        $on_tick += $step_ticks;
    }
}

sub velocity ($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}