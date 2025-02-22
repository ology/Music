#!/usr/bin/env perl

# Examples:
# perl rtmidi.pl --named="Beethoven In" --bpm=97 --phrase="G4,en G4,en G4,en Eb4,wn F4,en F4,en F4,en D4,wn"

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(setup_score midi_format score2events get_microseconds);
use Time::HiRes qw(usleep);

my %opt = (
    virtual => 'foo', #'perl-rtmidi',
    named   => 'bar', # or 'IAC Driver IAC Bus 1' or 'Logic Pro Virtual In', or anything?
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

my $micros = get_microseconds($score);

my $events = score2events($score);

# fire up RT-MIDI!
my $device = RtMidiOut->new;
# show open ports and then bail out
#for (0 .. $device->get_port_count - 1) { print $device->get_port_name($_), "\n" } exit;
$device->open_virtual_port($opt{virtual});
$device->open_port_by_name(qr/$opt{named}/i);

# send the events to the open port
sleep 1;
for my $event (@$events) {
    my $name = $event->[0];
    if ($name =~ /^note_\w+$/) {
        my $useconds = $micros * $event->[1];
        usleep($useconds) if $name eq 'note_off';
        $device->send_event($name => @{ $event }[ 2 .. 4 ]);
    }
}

$device->close_port;
