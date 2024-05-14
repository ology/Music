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
    virtual => 'perl-rtmidi',
    named   => 'Logic Pro Virtual In',
    phrase  => 'C5,hn G4,qn F4,en C4,sn',
    bpm     => 100,
);
GetOptions(\%opt,
    'virtual=s',
    'named=s',
    'phrase=s',
    'bpm=i',
);

my $score = setup_score(
    lead_in => 0,
    bpm     => $opt{bpm},
);

# add notes to the score
my @notes = split /\s+/, $opt{phrase};
for my $note (@notes) {
    my ($pitch, $duration) = split /,/, $note;
    $score->n($duration, $pitch);
}

# convert the score to an event list
my $events = MIDI::Score::score_r_to_events_r($score->{Score});

# fire up RT-MIDI!
my $device = RtMidiOut->new;
$device->open_virtual_port($opt{virtual});
$device->open_port_by_name($opt{named});

# compute the timing
my $tempo = first { $_->[0] eq 'set_tempo' } $score->{Score}->@*;
my $milliseconds = $tempo->[2] / $score->{Tempo}->$*;

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
