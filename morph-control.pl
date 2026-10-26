#!/usr/bin/env perl

# TODO Adjust joystick CC values.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port out_port);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'usb';

my %settings = (
     0 => 0, # y = pitch_wheel_change
     1 => 1, # x = modwheel
    10 => 10, # z = twist
    16 => 16, # " with button
    17 => 17, # "
    18 => 18, # "
);
my @joystick_ccs = sort { $a <=> $b } keys %settings;

my $midi_in = in_port($in_name);
say "Opened $midi_in for MIDI input.";
my $midi_out = out_port($out_name);
say "Opened $midi_out for MIDI output.";

while (1) { # TODO use IO::Async::Loop and friends, instead
    my $msg  = $midi_in->get_message_decoded;
    my $type = $msg->[0];
    my $cc   = $msg->[2];
    my $val  = $msg->[3];
    if ($msg && $type eq 'note_on') {
        print ddc($msg);
        if ($cc == 85) {
            assign_settings([qw(0 1 5 74 71 59)]);
        }
        elsif ($cc == 86) {
            assign_settings([qw(74 71 59 73 75 56)]);
        }
        elsif ($cc == 87) {
            assign_settings([qw(73 75 56 48 49 50)]);
        }
        elsif ($cc == 87) {
            assign_settings([qw(48 49 50 16 17 18)]);
        }
    }
    elsif ($msg && $type eq 'control_change') {
        $midi_out->cc(0, $settings{$cc}, $val);
    }
}

sub assign_settings ($ccs) {
    my $i = 0;
    for my $cc (@$ccs) {
        $settings{ $joystick_ccs[ $i++ ] } = $cc;
    }
}