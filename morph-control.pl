#!/usr/bin/env perl

# Adjust joystick CC value sending.

use v5.40;
use Time::HiRes qw(sleep);
use MIDI::RtMidi::Util qw(in_port out_port);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'iac';

# mode1=down: 0-18. mode2=up: 19-24
my @joystick_ccs = (0, 1, 10, 16, 17, 18, 19, 20, 21, 22, 23, 24);

# Button => CC list
my %modes = (
    85 => [qw(  0  1  5  74 71 59   47  52  53  60 62 56 )], # green
    86 => [qw( 74 71 59  73 75 56  102 103 105  82 83 91 )], # red
    87 => [qw( 73 75 56  48 49 50 )],                        # blue
    88 => [qw( 48 49 50  16 17 18 )],                        # yellow
);
my %settings = map { $_ => $_ } @joystick_ccs;   # default: pass-through

my $midi_in = in_port($in_name);
say "Opened $in_name for MIDI input.";
my $midi_out = out_port($out_name);
say "Opened $out_name for MIDI output.";

while (1) { # TODO use IO::Async::Loop and friends, instead
    my $msg = $midi_in->get_message_decoded;
    unless ($msg && @$msg) {
        sleep 0.001; # TODO why?
        next;
    }
    my ($type, $chan, @args) = @$msg;

    if ($type eq 'note_on') {
        my ($note) = @args;
        assign_settings($modes{$note}) if exists $modes{$note};
    }
    elsif ($type eq 'pitch_wheel_change') {
        my ($bend) = @args;
        my $val = ($bend + 8192) >> 7; # -8192..8191 => 0..127
        # say "P: $bend => $val";
        $midi_out->cc(0, $settings{0}, $val);
    }
    elsif ($type eq 'control_change') {
        my ($cc, $val) = @args;
        my $out_cc = $settings{$cc} // next; # ignore unmapped CCs
        # say "C: $cc => $out_cc, $val";
        $midi_out->cc(0, $out_cc, $val);
    }
}

sub assign_settings ($ccs) {
    die "Too many CCs (" . @$ccs . ") for " . @joystick_ccs . " joystick controls\n"
        if @$ccs > @joystick_ccs;
    say 'Assign settings';
    %settings = map { $_ => $_ } @joystick_ccs;
    @settings{ @joystick_ccs[ 0 .. $#$ccs ] } = @$ccs;
}