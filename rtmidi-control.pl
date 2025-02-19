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
            my $sleep = 500000;
            my $pitch = 60;
            single_note($midi_out, $msg, $pitch, $sleep);
        }
        elsif ($msg->[2] == 54 || $msg->[2] == 59) {
            my $sleep = 300000;
            my $pitch = 60;
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
        }
        elsif ($msg->[2] == 53 || $msg->[2] == 58 || $msg->[2] == 63) {
            my $sleep = 100000;
            my $pitch = 60;
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
        }
        elsif ($msg->[2] == 52 || $msg->[2] == 57 || $msg->[2] == 62 || $msg->[2] == 67) {
            my $sleep = 50000;
            my $pitch = 60;
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
            single_note($midi_out, $msg, $pitch, $sleep);
        }
        elsif ($msg->[2] == 84) {
            $midi_out->note_on($msg->[1], 64, $msg->[3]);
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
    usleep($t);
    $out->note_off(@$message[1], $note);
    usleep($t);
}

sub delay_effect {
    my ($out, $message, $note, $t, $feedback) = @_;
    for my $f (1 .. $feedback) {
        single_note($out, $message, $note, $t);
    }
}

__END__
