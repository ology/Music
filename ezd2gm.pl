#!/usr/bin/env perl

# Single track, EZdrummer to general midi converter
#
# EZdrummer has more articulations than the limited range of general
# midi, so information is lost by doing this.

use strict;
use warnings;

use MIDI ();

my $file = shift || die "Usage: perl $0 /some/midi/file.mid\n";

# EZdrummer midinums => general midi patches
my %map = (
    # closed hh
     11 => 42,
     22 => 42,
     61 => 42,
     62 => 42,
     63 => 42,
     65 => 42,
    122 => 42,
    # pedal hh
     10 => 44,
     21 => 44,
    # open hh
     12 => 46,
     13 => 46,
     14 => 46,
     15 => 46,
     16 => 46,
     17 => 46,
     24 => 46,
     25 => 46,
     26 => 46,
     60 => 46,
     64 => 46,
    120 => 46,
    121 => 46,
    122 => 46,
    123 => 46,
    124 => 46,
    # crash 1
     55 => 49,
     56 => 49,
     83 => 49,
     84 => 49,
     86 => 49,
     87 => 49,
    # crash 2
     27 => 57,
     28 => 57,
     49 => 57,
     50 => 57,
     88 => 57,
     89 => 57,
     90 => 57,
     91 => 57,
     92 => 57,
     93 => 57,
     94 => 57,
    # splash
     57 => 55,
     58 => 55,
     58 => 55,
    100 => 55,
    101 => 55,
    103 => 55,
    106 => 55,
    107 => 55,
    # china
     95 => 52,
     96 => 52,
     98 => 52,
     99 => 52,
    # ride 1
     29 => 51,
     52 => 51,
     54 => 51,
     59 => 51,
    104 => 51,
    108 => 51,
    111 => 51,
    113 => 51,
    116 => 51,
    118 => 51,
    # ride 2
     52 => 59,
     #59 => 59,
    110 => 59,
    115 => 59,
    119 => 59,
    # ride bell
     30 => 53,
     53 => 53,
     85 => 53,
     88 => 53,
     90 => 53,
     92 => 53,
     93 => 53,
     97 => 53,
    100 => 53,
    102 => 53,
    105 => 53,
    109 => 53,
    112 => 53,
    114 => 53,
    117 => 53,
    # snare
     33 => 38,
     #38 => 38,
     39 => 38,
     40 => 38,
     66 => 38,
     68 => 38,
     69 => 38,
     70 => 38,
     71 => 38,
     76 => 38,
    125 => 38,
    126 => 38,
    # sidestick
     #37 => 37,
     67 => 37,
    127 => 37,
    # kick
     34 => 35,
     #35 => 35,
     #36 => 36,
    # high-mid tom
     #48 => 48,
     81 => 48,
     82 => 48,
    # low-mid tom
     #47 => 47,
     79 => 47,
     80 => 47,
    # low tom
     #45 => 45,
     77 => 45,
     78 => 45,
    # floortom 1
     #43 => 43,
     74 => 43,
     75 => 43,
    # floortom 2
     #41 => 41,
     72 => 41,
     73 => 41,
    # tambourine
     3 => 54,
    # maracas
     2 => 70,
);

my $opus = MIDI::Opus->new({ from_file => $file });
my $ticks = $opus->ticks;

my @events;

for my $t ( $opus->tracks ) {
    my $score_r = MIDI::Score::events_r_to_score_r($t->events_r);

    # map the note events
    for my $event (@$score_r) {
        # ['note', <start>, <duration>, <channel>, <note>, <velocity>]
        if ($event->[0] eq 'note') {
            $event->[4] = $map{ $event->[4] } ? $map{ $event->[4] } : $event->[4];
        }
        push @events, $event;
    }
}

my $events_r = MIDI::Score::score_r_to_events_r(\@events);

my $track = MIDI::Track->new;
$track->events_r($events_r);

my $fresh = MIDI::Opus->new({ ticks => $ticks, tracks => [ $track ] });

$fresh->write_to_file("$0.mid");
