#!/usr/bin/env perl

# n.b. This works on my mac with Logic Pro X. Untested elsewhere.

use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);
use Getopt::Long qw(GetOptions);
use List::Util qw(first);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(setup_score score2events get_milliseconds);
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

my $millis = get_milliseconds($score);

my $events = score2events($score);

# fire up RT-MIDI!
my $device = RtMidiOut->new;
$device->open_virtual_port($opt{virtual});
$device->open_port_by_name($opt{named});

# send the events to the open port
for my $event (@$events) {
    my $name = $event->[0];
    if ($name =~ /^note_\w+$/) {
        my $useconds = $millis * $event->[1];
        usleep($useconds) if $name eq 'note_off';
        $device->send_event($name => @{ $event }[ 2 .. 4 ]);
    }
}
