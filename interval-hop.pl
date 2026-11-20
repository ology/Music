#!/usr/bin/env perl

# Bi-timbral generative sequence of phrases

# Examples:
# perl interval-hop.pl --verbose
# perl interval-hop.pl --verbose --bpm=90 --channels=0,1 --port=synth
# perl interval-hop.pl --v --b=90 --c=0,1 --p=synth # <- same

use v5.40;
use Data::Dumper::Compact qw(ddc);    # debugging
use Getopt::Long qw(GetOptions);      # cli processing
use IO::Async::Loop ();               # async
use IO::Async::Timer::Periodic ();    # async
use MIDI::RtMidi::Util qw(out_port);  # rt-midi
use MIDI::Util qw(dura_size TICKS);   # motif durations
use Music::Duration::Partition ();    # rhythmic phrases
use Music::Scales qw(get_scale_MIDI); # pitches
use Music::VoiceGen ();               # voices!

my %opt = (
    port     => 'nvision',   # required MIDI device name fragment
    channels => '1,2',       # two or more distinct midi channels (0 .. 15)
    bpm      => 70,          # beats-per-minute
    octave   => 2,           # 0 .. 9
    pitches  => 3,           # number of octaves
    scale    => 'minor',     # scale name
    tonic    => 'C',         # scale key base note
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

my @channels = split /\s*,\s*/, $opt{channels};
my @jumps    = split /\s*,\s*/, $opt{jumps};

# we are in 4/4 time...
my $ppqn           = MIDI::Util::TICKS;       # internal ticks per quarter-note = 96
my $clock_divider  = $ppqn / 24;              # MIDI clock is always 24 per quarter
my $phrase_ticks   = 4 * $ppqn;               # whole note = 384 ticks
my $clock_interval = 60 / $opt{bpm} / $ppqn;  # seconds per tick
my $ticks          = 0;                       # clock ticks
my $phrase_count   = 0;                       # quarter-notes played

my @active;  # { channel => $ch, note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { channel => $ch, note => $pitch, on_tick => $when_it_should_start }

my %voice;
for my ($i, $ch) (indexed @channels) {
    my @pool = map {
        get_scale_MIDI($opt{tonic}, $opt{octave} + $i + $_, $opt{scale})
    } 0 .. $opt{pitches} - 1;
    $voice{$ch} = Music::VoiceGen->new(
        pitches   => \@pool,
        intervals => \@jumps,
    );
}

my %phrase;
for my $ch (@channels) {
    $phrase{$ch} = Music::Duration::Partition->new(
        size => 4, # in quarter-notes
        pool => [qw(wn dhn hn dqn qn den en sn)],
    );
}

# open the midi device
my $midi_out = out_port($opt{port});
say "Opened '$opt{port}' for MIDI output" if $opt{verbose};

my $loop = IO::Async::Loop->new;

# Graceful ^C:
$loop->watch_signal(INT => sub {
    say "\nStop" if $opt{verbose};
    $midi_out->panic;
    $loop->stop;
});

my $timer = IO::Async::Timer::Periodic->new(
    interval   => $clock_interval,
    reschedule => 'hard', # anchor to a fixed schedule, don't let tempo drift
    on_tick    => sub {
        $ticks++;

        # send MIDI clock 24 times per quarter-note
        $midi_out->clock if ($ticks - 1) % $clock_divider == 0;

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($active[$i]{channel}, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # start a new phrase on every quarter-note boundary
        if (($ticks - 1) % $phrase_ticks == 0) {
            trigger_notes($phrase_count);
            $phrase_count++;
        }

        # fire any pending notes whose time has come
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
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub trigger_notes ($i) {
    for my $ch (@channels) {
        my $motif   = $phrase{$ch}->motif;
        my $on_tick = $ticks;
        for my $duration ($motif->@*) {
            my $length = int(dura_size($duration) * $ppqn + 0.5) || 1;
            push @pending, {
                channel  => $ch,
                note     => $voice{$ch}->rand,
                on_tick  => $on_tick,
                off_tick => $on_tick + $length,
            };
            $on_tick += $length;
        }
        say "$i. Channel $ch: ", join(' ', $motif->@*) if $opt{verbose};
    }
}

sub velocity ($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}