#!/usr/bin/env perl
use v5.36;

use Data::Dumper::Compact qw(ddc);
use Future::AsyncAwait;
use IO::Async::Timer::Periodic;
use IO::Async::Routine;
use IO::Async::Channel;
use IO::Async::Loop;
use MIDI::RtMidi::FFI::Device;
use Time::HiRes qw(usleep);

my $port = shift || 'tempopad';

my $loop = IO::Async::Loop->new;
my $midi_ch = IO::Async::Channel->new;

my $midi_rtn = IO::Async::Routine->new(
    channels_out => [ $midi_ch ],
    code => sub {
        my $midi_in = MIDI::RtMidi::FFI::Device->new( type => 'in' );
        $midi_in->open_port_by_name(qr/\Q$port/i);

        $midi_in->set_callback_decoded(
            sub { $midi_ch->send($_[2]) }
        );

        sleep;
    }
);
$loop->add( $midi_rtn );

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/fluid/i);

$SIG{TERM} = sub { $midi_rtn->kill('TERM') };

async sub process_midi_events {
    while (my $event = await $midi_ch->recv) {
        # warn ddc $event;
        single_note($midi_out, $event, 500_000);
        # $midi_out->note_on(@$event[1 .. 3]);
        # usleep(100_000);
        # $midi_out->note_off($event->[1], $event->[3]);
        $midi_out->note_on(@$event[1 .. 3]);
        # delay_effect($midi_out, $event, 500_000, 3);
    }
}

my $tick = 0;
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub { say "Tick " . $tick++; },
    )->start
);

$loop->await(process_midi_events);

sub single_note {
    my ($out, $message, $t) = @_;
    $out->note_on(@$message[1 .. 3]);
    if ($t) {
        usleep($t);
        $out->note_off($message->[1], $message->[3]);
    }
}

sub delay_effect {
    my ($out, $message, $t, $feedback) = @_;
    for my $f (1 .. $feedback) {
        single_note($out, $message, $t);
    }
}
