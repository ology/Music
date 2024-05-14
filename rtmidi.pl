#!/usr/bin/env perl

# This works on my mac with Logic Pro X. Untested elsewhere.

use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);
use MIDI::Util qw(setup_score);
use Getopt::Long qw(GetOptions);
use List::Util qw(first);
use MIDI::RtMidi::FFI::Device;
use Time::HiRes qw(usleep);

my %opt = (
    virtual  => 'perl-rtmidi',
    named    => 'Logic Pro Virtual In',
    duration => -1, # -1 = random select from pool. 'qn' = quarter-note, etc.
    bpm      => 100,
);
GetOptions(\%opt,
    'virtual=s',
    'port=s',
    'duration=s',
);

my @durations = qw(wn hn qn en sn);

my $score = setup_score(
    lead_in => 0,
    bpm     => $opt{bpm},
);

my $tempo = first { $_->[0] eq 'set_tempo' } $score->{Score}->@*;
my $milliseconds = $tempo->[2] / $score->{Tempo}->$*;

# add notes to the score
for my $pitch (qw(C5 G4 F4 C4)) {
    my $duration = $opt{duration} eq '-1' ? $durations[int rand @durations] : $opt{duration};
    $score->n($duration, $pitch);
}

# convert the score to an event list
my $events = MIDI::Score::score_r_to_events_r($score->{Score});

# fire up RT-MIDI!
my $device = RtMidiOut->new;
$device->open_virtual_port($opt{virtual});
$device->open_port_by_name($opt{named});

# send the events to the open port
sleep 1;
for my $event (@$events) {
    my $name = $event->[0];
    if ($name =~ /^note_\w+$/) {
        my $useconds = $milliseconds * $event->[1];
        usleep($useconds) if $name eq 'note_off';
        $device->send_event($name => @{ $event }[ 2 .. 4 ]);
    }
}
