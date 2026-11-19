#!/usr/bin/env perl

# Play a generative sequence that jumps by musical interval.
# Each MIDI channel gets its own independent voice, and play
# simultaneously.

# Examples:
# perl interval-hop.pl --verbose --po=nvision
# perl interval-hop.pl --v --b=90 --channels=0,1 --po=synth

use v5.40;
use Data::Dumper::Compact qw(ddc);    # debugging
use Getopt::Long qw(GetOptions);      # cli processing
use IO::Async::Loop ();               # async
use IO::Async::Timer::Periodic ();    # async
use MIDI::RtMidi::Util qw(out_port stop_all_notes); # rt-midi
use Music::Scales qw(get_scale_MIDI); # pitches
use Music::VoiceGen ();               # voices!

my %opt = (
    port     => undef,       # required MIDI device name fragment
    bpm      => 70,          # beats-per-minute
    channels => '1,2',       # two or more distinct midi channels (0 .. 15)
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
    'channels=s',
    'octave=i',
    'scale=s',
    'tonic=s',
    'jumps=s',
    'verbose',
);

die "Open MIDI port name required for 'port'\n" unless $opt{port};

my @channels = split /\s*,\s*/, $opt{channels};

# we are in 4/4 time...
my $divisions       = 4; # divisions of a quarter-note into 16ths
my $beats           = $divisions * $divisions; # beats in a phrase
my $clocks_per_beat = 6 * $divisions; # PPQN
my $clock_interval  = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn

my @active;  # { channel => $ch, note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { channel => $ch, note => $pitch, on_tick => $when_it_should_start }

my $ticks      = 0; # clock ticks
my $beat_count = 0; # beats!

my @pitches = map { get_scale_MIDI($opt{tonic}, $opt{octave}, $opt{scale}) } 1 .. $opt{pitches};
my @jumps = split /,/, $opt{jumps};

# one independent voice per channel
my %voice = map {
    $_ => Music::VoiceGen->new(
        pitches   => \@pitches,
        intervals => \@jumps,
    )
} @channels;

# open the midi devices for output
my $midi_out = out_port($opt{port});
say "Opened '$opt{port}' for MIDI output" if $opt{verbose};

my $loop = IO::Async::Loop->new;

# Graceful ^C:
$loop->watch_signal(INT => sub {
    say "\nStop" if $opt{verbose};
    stop_all_notes($midi_out);
    $midi_out->cc($_, 123, 0) for @channels;
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
                $midi_out->note_off($active[$i]{channel}, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending arp notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($p->{channel}, $p->{note}, velocity(-10, 10, 110));
            push @active, {
                channel  => $p->{channel},
                note     => $p->{note},
                off_tick => $p->{off_tick},
            };
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
    my $step_ticks = 4;
    for my $ch (@channels) {
        my @notes   = map { $voice{$ch}->rand } 1 .. 4;
        my $on_tick = $ticks;
        for my $n (@notes) {
            push @pending, {
                channel  => $ch,
                note     => $n,
                on_tick  => $on_tick,
                off_tick => $on_tick + $step_ticks,
            };
            $on_tick += $step_ticks;
        }
    }
}

sub velocity ($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}