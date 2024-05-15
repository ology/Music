#!/usr/bin/env perl

# n.b. This works on my mac with Logic Pro X - which you need to have open. Untested elsewhere.

# Examples:
# perl rtmidi.pl --named="Foo Bar In" --bpm=97 --phrase="G4,en G4,en G4,en F4,wn"

use strict;
use warnings;

#use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util); # n.b. local author libs. comment this out unless you're me
use Getopt::Long qw(GetOptions);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(setup_score midi_format score2events get_milliseconds);
use Time::HiRes qw(usleep);

my %opt = (
    virtual => 'perl-rtmidi',
    named   => 'Logic Pro Virtual In',
    bpm     => 100,
    phrase  => 'C5,sn G4,en F4,qn C5,sn G4,en F4,qn C4,wn',
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
    $score->n($duration, midi_format($pitch));
}

my $millis = get_milliseconds($score);

my $events = score2events($score);

# fire up RT-MIDI!
my $device = RtMidiOut->new;
$device->open_virtual_port($opt{virtual});
$device->open_port_by_name($opt{named});

# send the events to the open port
sleep 1;
for my $event (@$events) {
    my $name = $event->[0];
    if ($name =~ /^note_\w+$/) {
        my $useconds = $millis * $event->[1];
        usleep($useconds) if $name eq 'note_off';
        $device->send_event($name => @{ $event }[ 2 .. 4 ]);
    }
}
