#!/usr/bin/env perl

# Adjust joystick CC value sending.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use Math::Utils qw(uniform_scaling);
use MIDI::RtMidi::Util qw(in_port out_port);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'se-02';

my %settings = (
    # mode=up
     1 => 1,  # x = modwheel
     0 => 0,  # y = pitch_wheel_change
    10 => 10, # z = twist
    16 => 16, # " with button
    17 => 17, # "
    18 => 18, # "
    # mode=down
    19 => 19, # x
    20 => 20, # y
    21 => 21, # z
    22 => 22, # " with button
    23 => 23,
    24 => 24,
);
my @joystick_ccs = sort { $a <=> $b } keys %settings;

my $midi_in = in_port($in_name);
say "Opened $midi_in for MIDI input.";
my $midi_out = out_port($out_name);
say "Opened $midi_out for MIDI output.";

while (1) { # TODO use IO::Async::Loop and friends, instead
    my $msg = $midi_in->get_message_decoded;
    next unless $msg;
    my $type = $msg->[0];
    # my $chan = $msg->[1];
    my $cc   = $msg->[2];
    my $val  = $msg->[3];
    if ($type && $type eq 'note_on') {
        if ($cc == 85) { # green
            assign_settings([qw(
                0 1 5
                74 71 59
                47 52 53
                60 62 56
            )]);
        }
        elsif ($cc == 86) { # red
            assign_settings([qw(
                74 71 59
                73 75 56
                102 103 105
                82 83 91
            )]);
        }
        elsif ($cc == 87) { # blue
            assign_settings([qw(
                73 75 56
                48 49 50
            )]);
        }
        elsif ($cc == 88) { # yellow
            assign_settings([qw(
                48 49 50
                16 17 18
            )]);
        }
    }
    elsif ($type && defined $cc && $type eq 'pitch_wheel_change') {
        my ($scaled) = uniform_scaling([-8192, 8192], [0, 127], $cc);
        say "P: $cc => $scaled";
        $midi_out->cc(0, $settings{0}, $scaled);
    }
    elsif ($type && defined $cc && defined $val && $type eq 'control_change') {
        say "C: $cc, $settings{$cc}, $val";
        $midi_out->cc(0, $settings{$cc}, $val);
    }
}

sub assign_settings ($ccs) {
    my $i = 0;
    for my $cc (@$ccs) {
        $settings{ $joystick_ccs[ $i++ ] } = $cc;
    }
}