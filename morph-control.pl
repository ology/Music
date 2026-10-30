#!/usr/bin/env perl

# Adjust joystick CC value sending.

use v5.40;
use Time::HiRes qw(sleep);
use MIDI::Device ();
use MIDI::RtMidi::Util qw(in_port out_port);

use constant CC => 'control_change';

my $in_name  = shift || 'joystick';
my $out_name = shift || 'iac';

my $joystick = MIDI::Device->new(name => 'midi-rock-stone');
my @joystick_ccs = (
    0, 1, 10,
    16, 17, 18,
    19, 20, 21,
    22, 23, 24
);

my $se02 = MIDI::Device->new(name => 'se-02');
my $sets => {
    filter => [
        $se02->find(CC, 'Filter Cutoff Frequency'),     # 74
        $se02->find(CC, 'Filter Emphasis (Resonance)'), # 71
        $se02->find(CC, 'Filter Contour'),              # 59
    ],
    filter1 => [
        $se02->find(CC, 'Filter Attack 1'),  # 47
        $se02->find(CC, 'Filter Decay 1'),   # 52
        $se02->find(CC, 'Filter Sustain 1'), # 53
    ],
    filter2 => [
        $se02->find(CC, 'Filter Attack 2'),  # 73
        $se02->find(CC, 'Filter Decay 2'),   # 75
        $se02->find(CC, 'Filter Sustain 2'), # 56
    ],
    lfo => [
        $se02->find(CC, 'LFO Rate'),         # 102
        $se02->find(CC, 'LFO OSC Depth'),    # 103
        $se02->find(CC, 'LFO Filter Depth'), # 105
    ],
    delay => [
        $se02->find(CC, 'Delay Time'),   # 82
        $se02->find(CC, 'Delay Regen'),  # 83
        $se02->find(CC, 'Delay Amount'), # 91
    ],
    osc => [
        $se02->find(CC, 'OSC 1 Level'), # 48
        $se02->find(CC, 'OSC 2 Level'), # 49
        $se02->find(CC, 'OSC 3 Level'), # 50
    ],
    xmod => [
        $se02->find(CC, 'XMOD O2 to Filter'),      # 16
        $se02->find(CC, 'XMOD O3 to O2'),          # 17
        $se02->find(CC, 'XMOD O3 to Pulse Width'), # 18
    ],
    misc => [
        $se02->find(CC, 'Glide Time'),     # 5
        $se02->find(CC, 'Feedback Level'), # 51
        $se02->find(CC, 'Noise Level'),    # 41
    ],
};
# set values keyed by midi note number
my %modes = (
    85 => [ $sets->{qw(filter filter1 filter1 filter)}->@* ], # green
    86 => [ $sets->{qw(lfo filter2 filter2 lfo)}->@* ], # red
    87 => [ $sets->{qw(delay osc osc delay)}->@* ], # blue
    88 => [ $sets->{qw(xmod misc misc xmod)}->@* ], # yellow
);
my %settings = map { $_ => $_ } @joystick_ccs;

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