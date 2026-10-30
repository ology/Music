#!/usr/bin/env perl

# Adjust joystick CC value sending.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use MIDI::Device ();
use MIDI::RtMidi::Util qw(in_port out_port);
use Time::HiRes qw(sleep);

my $in_name  = shift || 'joystick';
my $out_name = shift || 'iac';

my $joystick = MIDI::Device->new(
    name   => 'midi-rock-stone',
    shared => $ENV{HOME} . '/sandbox/MIDI-Device/share/',
);
my @joystick_ccs = (
    0,                                  # pitch-bend
    find_it($joystick, 'x mode 1'),     # 1
    find_it($joystick, 'twist mode 1'), # 10

    find_it($joystick, 'x mode 1 button'),     # 16
    find_it($joystick, 'y mode 1 button'),     # 17
    find_it($joystick, 'twist mode 1 button'), # 18

    find_it($joystick, 'x mode 2'),     # 19
    find_it($joystick, 'y mode 2'),     # 20
    find_it($joystick, 'twist mode 2'), # 21

    find_it($joystick, 'x mode 2 button'),     # 22
    find_it($joystick, 'y mode 2 button'),     # 23
    find_it($joystick, 'twist mode 2 button'), # 24
);

my %settings = map { $_ => $_ } @joystick_ccs;

my $se02 = MIDI::Device->new(
    name   => 'se-02',
    shared => $ENV{HOME} . '/sandbox/MIDI-Device/share/',
);
my $sets = {
    filter => [
        find_it($se02, 'Filter Cutoff Frequency'), # 74
        find_it($se02, 'Filter Emphasis'),         # 71
        find_it($se02, 'Filter Contour'),          # 59
    ],
    filter1 => [
        find_it($se02, 'Filter Attack 1'),  # 47
        find_it($se02, 'Filter Decay 1'),   # 52
        find_it($se02, 'Filter Sustain 1'), # 53
    ],
    filter2 => [
        find_it($se02, 'Filter Attack 2'),  # 73
        find_it($se02, 'Filter Decay 2'),   # 75
        find_it($se02, 'Filter Sustain 2'), # 56
    ],
    lfo => [
        find_it($se02, 'LFO Rate'),         # 102
        find_it($se02, 'LFO OSC Depth'),    # 103
        find_it($se02, 'LFO Filter Depth'), # 105
    ],
    delay => [
        find_it($se02, 'Delay Time'),   # 82
        find_it($se02, 'Delay Regen'),  # 83
        find_it($se02, 'Delay Amount'), # 91
    ],
    osc => [
        find_it($se02, 'OSC 1 Level'), # 48
        find_it($se02, 'OSC 2 Level'), # 49
        find_it($se02, 'OSC 3 Level'), # 50
    ],
    xmod => [
        find_it($se02, 'XMOD O2 to Filter'),      # 16
        find_it($se02, 'XMOD O3 to O2'),          # 17
        find_it($se02, 'XMOD O3 to Pulse Width'), # 18
    ],
    misc => [
        find_it($se02, 'Glide Time'),     # 5
        find_it($se02, 'Feedback Level'), # 51
        find_it($se02, 'Noise Level'),    # 41
    ],
};

# set values keyed by midi note number
my %modes = (
    85 => [ $sets->@{qw(filter filter1 filter1 filter)} ], # green
    86 => [ $sets->@{qw(lfo filter2 filter2 lfo)} ], # red
    87 => [ $sets->@{qw(delay osc osc delay)} ], # blue
    88 => [ $sets->@{qw(xmod misc misc xmod)} ], # yellow
);

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
    say ddc $msg;
    if ($type eq 'note_on') {
        my ($note) = @args;
        assign_settings($modes{$note}) if exists $modes{$note};
    }
    elsif ($type eq 'pitch_wheel_change') {
        my ($bend) = @args;
        my $val = ($bend + 8192) >> 7; # -8192..8191 => 0..127
        say "P: $bend => $val";
        say ddc \%settings;
        $midi_out->cc(0, $settings{0}, $val);
    }
    elsif ($type eq 'control_change') {
        my ($cc, $val) = @args;
        my $out_cc = $settings{$cc} // next; # ignore unmapped CCs
        say "C: $cc => $out_cc, $val";
        say ddc \%settings;
        $midi_out->cc(0, $out_cc, $val);
    }
}

sub assign_settings ($ccs) {
    die "Too many CCs (" . @$ccs . ") for " . @joystick_ccs . " joystick controls\n"
        if @$ccs > @joystick_ccs;
    say "Assign settings: @$ccs";
    %settings = map { $_ => $_ } @joystick_ccs;
    @settings{ @joystick_ccs[ 0 .. $#$ccs ] } = @$ccs;
}

sub find_it ($device, $note) {
    return $device->find('control_change', $note)->[0]{number};
}