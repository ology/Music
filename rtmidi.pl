#!/usr/bin/env perl

# This works on my mac with Logic Pro X. Untested elsewhere.

use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(MIDI-Util);
use MIDI::Util qw(setup_score);

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use MIDI::RtMidi::FFI::Device;

my %opt = (
    port => 'Logic Pro Virtual In',
);
GetOptions(\%opt,
    'port=s',
);

my $score = setup_score();

$score->n('qn', 'C5');
$score->n('qn', 'G4');
$score->n('qn', 'F4');
$score->n('qn', 'C4');

my $events = MIDI::Score::score_r_to_events_r($score->{Score});

my $device = RtMidiOut->new;
$device->open_virtual_port($opt{port});
$device->open_port_by_name($opt{port});

for my $event (@$events) {
    if ($event->[0] =~ /^(note_\w+)$/) {
        #use DDP; p $event;
        my $op = $1;
        $device->send_event($op => @{ $event }[ 2 .. 4 ]);
        sleep 1 if $op eq 'note_on';
    }
}
