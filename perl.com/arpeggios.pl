#!/usr/bin/env perl

# Play arpeggios on a MIDI device with a clock.

use v5.36;
# use Data::Dumper::Compact qw(ddc);               # debugging
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use List::Util qw(max sum0);                     # arp-duration scaling
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use Music::MelodicDevice::Arpeggiation ();       # arpeggiation
use Music::Scales qw(get_scale_MIDI);            # pitches

use constant ARP_TICKS => Music::MelodicDevice::Arpeggiation::TICKS();

my %opt = (
    y_port   => 'synth', # REQUIRED MIDI device (e.g. microKorg)
    bpm      => 80,      # beats-per-minute
    arp_type => 'any',   # 'any' or any known arp_type
    note_num => '5,7',   # number of arp notes
    repeats  => 1,       # number of arp-phrase repeats
    duration => 1,       # 0.1 .. 4 float
    octave   => '3,4,5', # octaves (0 .. 9 ints)
    scale    => 'minor', # scale name as known to Music::Scales
    tonic    => 'C',     # scale key base note
    spread   => 4,       # beats an arp should stretch across
);

die "Open MIDI port name required for 'y_port'\n" unless $opt{y_port};

my $arper = Music::MelodicDevice::Arpeggiation->new(
    repeats => $opt{repeats},
    verbose => 1,
);

# split things
my @octave    = split /,/, $opt{octave};
my @note_nums = split /,/, $opt{note_num};
my @arp_types = $opt{arp_type} eq 'any'
    ? keys $arper->arp_type->%*
    : split /,/, $opt{arp_type};

# get range of pitches by octave
my @pitches = map { get_scale_MIDI($opt{tonic}, $_, $opt{scale}) } @octave;

say "Arp types: $opt{arp_type}";
say "Arp nums: $opt{note_num}";
say "Pitches: @pitches";

my $channel = 0; # this code talks to a single channel

# we are in 4/4 time...
my $divisions       = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 6 * $divisions; # PPQN
my $clock_interval  = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn

my $phrase_beats = $opt{spread} || $divisions;

my @active;  # { note => $pitch, off_tick => $when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $when_it_should_start }

my $ticks      = 0; # clock ticks
my $beat_count = 0; # beats!

# open the midi devices for output
my $midi_out = out_port($opt{y_port});
$midi_out->start;
say "Started $opt{y_port}";

$SIG{INT} = sub {
    say "\nStop";
    stop_device($midi_out);
    exit(0);
};

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($channel, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending arp notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($channel, $p->{note}, velocity());
            push @active, { note => $p->{note}, off_tick => $p->{off_tick} };
        }

        if (($ticks - 1) % $clocks_per_beat == 0) {
            if ($beat_count % $phrase_beats == 0) { # retrigger every $phrase_beats beats
                trigger_notes();
            }
            $beat_count++;
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub trigger_notes {
    # get a number of random pitches based on a random @note_nums value. Confused? :)
    my @notes = sort { $a <=> $b }
        map { $pitches[int rand @pitches] } 1 .. $note_nums[int rand @note_nums]; # XXX klunky

    # get an arpeggiated note list given a random arp_type
    my $arped = $arper->arp(\@notes, $opt{duration}, $arp_types[int rand @arp_types]);

    # convert from the arp's 96-ticks-per-quarter-note scale to our clock ticks
    my @raw_ticks = map {
        my ($dur) = $_->[0] =~ /^d(\d+)$/;
        max(1, int($dur * $clocks_per_beat / ARP_TICKS));
    } @$arped;

    # stretch or squeeze the arp, so it spans the 'spread' number of beats
    my $scale = 1;
    if ($opt{spread}) {
        my $raw_total = sum0(@raw_ticks) || 1;
        my $available = $opt{spread} * $clocks_per_beat;
        $scale = $available / $raw_total;
    }

    my $on_tick = $ticks + 1;

    for my $i (0 .. $#$arped) {
        my (undef, $note) = @{ $arped->[$i] }; # nb: a note is a duration and a pitch
        my $step_ticks = max(1, int($raw_ticks[$i] * $scale));

        push @pending, {
            note     => $note,
            on_tick  => $on_tick,
            off_tick => $on_tick + $step_ticks,
        };

        $on_tick += $step_ticks;
    }
}

sub velocity ($min=-10, $max=10, $offset=110) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}