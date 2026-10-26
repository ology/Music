#!/usr/bin/env perl

# Adjust joystick CC values.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port out_port stop_all_notes);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'usb';
my $bpm      = shift || 60;

my $divisions       = 4;
my $clocks_per_beat = 6 * $divisions; # PPQN
my $clock_interval  = 60 / $bpm / $clocks_per_beat; # time / bpm / ppqn

my $ticks      = 0;
my $beat_count = 0;

my $midi_in  = in_port($in_name);
my $midi_out = out_port($out_name);
say "Opened $midi_in for MIDI input.";
say "Opened $midi_out for MIDI output.";

$SIG{INT} = sub {
    say "\nStop";
    stop_all_notes($midi_out);
    exit;
};

while (1) {
    my $msg = $midi_in->get_message_decoded;
    if ($msg && $msg->[0] eq 'note_on') {
        print ddc($msg);
        if ($msg->[2] == 85) {
            say 'Sending 85 to $midi_out...';
        }
        elsif ($msg->[2] == 86) {
            say 'Sending 86 to $midi_out...';
        }
    }
}

sub send_it ($port, $event) {
    $port->send_event($event->@*);
}
