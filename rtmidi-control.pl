#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::FFI::Device ();
use Time::HiRes qw(usleep);

my $midi_in = RtMidiIn->new;
$midi_in->open_port_by_name(qr/tempopad/i);

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/fluid/i);

while (1) {
    my $msg = $midi_in->get_message_decoded;
    if ($msg && $msg->[0] eq 'note_on') {
        warn ddc($msg);
        if ($msg->[2] == 55) {
            delay_effect($midi_out, $msg, 60, 0, 1);
        }
        elsif ($msg->[2] == 54 || $msg->[2] == 59) {
            delay_effect($midi_out, $msg, 60, 500_000, 2);
        }
        elsif ($msg->[2] == 53 || $msg->[2] == 58 || $msg->[2] == 63) {
            delay_effect($midi_out, $msg, 60, 300_000, 3);
        }
        elsif ($msg->[2] == 52 || $msg->[2] == 57 || $msg->[2] == 62 || $msg->[2] == 67) {
            delay_effect($midi_out, $msg, 60, 200_000, 4);
        }
        elsif ($msg->[2] == 56 || $msg->[2] == 61 || $msg->[2] == 66) {
            delay_effect($midi_out, $msg, 60, 100_000, 5);
        }
        elsif ($msg->[2] == 60 || $msg->[2] == 65) {
            delay_effect($midi_out, $msg, 60, 80_000, 6);
        }
        elsif ($msg->[2] == 64) {
            delay_effect($midi_out, $msg, 60, 60_000, 7);
        }
        elsif ($msg->[2] == 84) {
            delay_effect($midi_out, $msg, 64, 0, 1);
        }
        elsif ($msg->[2] == 88 || $msg->[2] == 85) {
            delay_effect($midi_out, $msg, 64, 500_000, 2);
        }
        elsif ($msg->[2] == 92 || $msg->[2] == 89 || $msg->[2] == 86) {
            delay_effect($midi_out, $msg, 64, 300_000, 3);
        }
        elsif ($msg->[2] == 96 || $msg->[2] == 93 || $msg->[2] == 90 || $msg->[2] == 87) {
            delay_effect($midi_out, $msg, 64, 200_000, 4);
        }
        elsif ($msg->[2] == 97 || $msg->[2] == 94 || $msg->[2] == 91) {
            delay_effect($midi_out, $msg, 64, 100_000, 5);
        }
        elsif ($msg->[2] == 98 || $msg->[2] == 95) {
            delay_effect($midi_out, $msg, 64, 80_000, 6);
        }
        elsif ($msg->[2] == 99) {
            delay_effect($midi_out, $msg, 64, 60_000, 7);
        }
        elsif ($msg->[2] == 80) {
            $midi_out->note_on($msg->[1], 67, $msg->[3]);
        }
        elsif ($msg->[2] == 51) {
            $midi_out->note_on($msg->[1], 71, $msg->[3]);
        }
    }
}

sub single_note {
    my ($out, $message, $note, $t) = @_;
    $out->note_on($message->[1], $note, $message->[3]);
    if ($t) {
        usleep($t);
        $out->note_off(@$message[1], $note);
    }
}

sub delay_effect {
    my ($out, $message, $note, $t, $feedback) = @_;
    for my $f (1 .. $feedback) {
        single_note($out, $message, $note, $t);
    }
}
