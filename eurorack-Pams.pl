#!/usr/bin/env perl

# perl eurorack-trinity.pl 60

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(out_port halt);
use MIDI::RtMidi::FFI::Device ();
use Music::Scales qw(get_scale_MIDI);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use POSIX qw(_exit); # skip global destruction
no warnings 'experimental::try';

my $bpm  = shift || 70; # beats-per-minute
my $port = shift || 'midithing'; # MIDI device
my $seq  = shift || 'sq-1'; # MIDI device

# choose the pitches to use
my @pitches = (
  get_scale_MIDI('C', 0, 'pminor'),
  get_scale_MIDI('C', 1, 'minor'),
);

my $channel = 0;

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $note_duration_ticks = $clocks_per_beat * $divisions;
my $group_interval_beats = $beats / $divisions; # trigger a note group every N beats
my @active; # { note => $pitch, off_tick => $tick_when_it_should_stop }

my $midi_out = out_port($port);
$midi_out->start;

my $device = out_port($seq);
$device->start;

$SIG{INT} = sub {
    say "\nStop";
    halt($midi_out);
    _exit(0);
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

        if ($ticks % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) {
                # The microKORG needs real time to load the new patch
                # before it'll reliably respond. So delay_future()
                # waits the same amount of time without blocking.
                $loop->delay_future(after => 0.1)->on_done(sub {
                    trigger_notes();
                })->retain; # keep the Future alive until it fires
            }
            elsif ($beat_count % $group_interval_beats == 0) {
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
    my $note = $pitches[int rand @pitches];
    say "N: $note";
    $midi_out->note_on($channel, $note, velocity(-10, 10, 110));
    push @active, { note => $note, off_tick => $ticks + $note_duration_ticks };
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}