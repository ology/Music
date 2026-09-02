#!/usr/bin/env perl

# Ex: perl arping.pl 60 pad usb

use v5.36;
use feature 'try';
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(out_port stop_device);
use MIDI::RtMidi::FFI::Device ();
use Music::MelodicDevice::Arpeggiation ();
use Music::Scales qw(get_scale_MIDI);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use POSIX qw(_exit); # skip global destruction
no warnings 'experimental::try';

my $bpm      = shift || 70; # beats-per-minute
my $port     = shift || 'se-02'; # MIDI device
my $clocked  = shift || 'usb';   # MIDI device
my $arp_type = shift || 'up';

# choose the pitches to use
my @pitches = (
  get_scale_MIDI('C', 2, 'pminor'),
  get_scale_MIDI('C', 3, 'minor'),
);

my $channel = 0;

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $note_duration_beats = 4; # how long each triggered note rings for
my $note_duration_ticks = $clocks_per_beat * $note_duration_beats;
my $group_interval_beats = $beats / $divisions; # trigger a note group every N beats
my $arp_step_ticks = int($clocks_per_beat / 4); # spacing between arp notes (16th notes)
my @active;  # { note => $pitch, off_tick => $tick_when_it_should_stop }
my @pending; # { note => $pitch, on_tick => $tick_when_it_should_start }

# open the midi devices for output
my $midi_out = out_port($port);
$midi_out->start;

my $device = out_port($clocked);
$device->start;

my $arper = Music::MelodicDevice::Arpeggiation->new;

$SIG{INT} = sub {
    say "\nStop";
    stop_device($midi_out);
    stop_device($device);
    # skip global destruction, as the cleanup has already been done
    _exit(0);
};

my @programs = (0 .. 127);

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $device->clock;
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
            $midi_out->note_on($channel, $p->{note}, velocity(-10, 10, 110));
            push @active, { note => $p->{note}, off_tick => $ticks + $note_duration_ticks };
        }

        if ($ticks % $clocks_per_beat == 0) {
            if ($beat_count % $beats == 0) {
                # change microKORG programs - why not?
                my $program = $programs[int rand @programs];
                say "PC: $program";
                $midi_out->program_change($channel, $program);

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
    my @notes = sort { $a <=> $b }
        map { $pitches[int rand @pitches] } 1 .. 4;
    my $arped = $arper->arp(\@notes, 1, $arp_type);
    say "N,A: @notes => ", ddc $arped;
    for my $i (0 .. $#$arped) {
        push @pending, {
            note    => $arped->[$i][1],
            on_tick => $ticks + $i * $arp_step_ticks,
        };
    }
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}