#!/usr/bin/env perl

# Play Euclidean patterns and snare fills with no clock.
# Example: perl multi-timbral-drum-fills.pl usb 90

use v5.36;
# use IO::Async::Loop (); # TODO
# use IO::Async::Timer::Periodic ();
use Math::Prime::Util::PrimeIterator ();
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::FFI::Device ();
use Music::CreatingRhythms ();
use Music::Duration::Partition ();
use Time::HiRes qw(sleep);

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120;

my $machine = DrumMachine->new($bpm);
$machine->run($name);

package DrumMachine;
use Try::Tiny;

sub new($class, $bpm) {
    my $self;
    $self->{beats} = 16;
    # get a list of primes less than or equal to beats
    my @primes;
    my $it = Math::Prime::Util::PrimeIterator->new;
    my $p = $it->iterate;
    while ($p <= $self->{beats}) {
        push @primes, $p;
        $p = $it->iterate;
    }
    $self->{primes}  = \@primes;
    $self->{notes}   = [60, 64, 67];
    $self->{bpm}     = $bpm;
    $self->{per_sec} = 60 / $bpm;
    $self->{dura}    = $self->{per_sec} / 4;
    $self->{N}       = 0;
    $self->{outport} = undef;
    $self->{drums}   = {
        kick    => { num => 36, chan => 0 },
        snare   => { num => 38, chan => 1 },
        hihat   => { num => 42, chan => 2 },
        cymbals => { num => 49, chan => 3 },
    };
    $self->{voices}   = keys $self->{drums}->%*;
    $self->{chans}    = [ map { $_->{chan} } values $self->{drums}->%* ];
    $self->{r}        = Music::CreatingRhythms->new;
    $self->{patterns} = {
        kick    => $self->{r}->euclid(2, $self->{beats}),
        snare   => $self->{r}->rotate_n(4, $self->{r}->euclid(2, $self->{beats})),
        hihat   => $self->{r}->euclid(11, $self->{beats}),
        cymbals => [ 0 .. $self->{beats} ],
    };
    return bless $self, $class;
}

sub midi_msg($self, $event, $note, $channel, $velocity) {
    $self->{outport}->send_event($event, $channel, $note, $velocity);
}

sub velo($self, $min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

sub random_note($self) {
    my @notes = $self->{notes}->@*;
    return $notes[ int rand @notes ] - 24;
}

sub part($self, $i, $n) {
    $n ||= $self->{beats};
    $self->adjust_groove($i);
    for my $step (0 .. $n) {
        for my $drum ($self->{voices}) {
            if ($self->{patterns}{$drum}[$step]) {
                $self->midi_msg('note_on', $self->{drums}{$drum}{num}, $self->{drums}{$drum}{chan}, $self->velo);
            }
        }
        sleep($self->{dura} * 0.9);
        for my $drum ($self->{voices}) {
            if ($self->{patterns}{$drum}[$step]) {
                $self->midi_msg('note_off', $self->{drums}{$drum}{num}, $self->{drums}{$drum}{chan}, 0);
            }
        }
        sleep($self->{dura} * 0.1);
    }
}

sub fill($self, $measure_size) {
    my $rr = Music::Duration::Partition->new(
        size      => $measure_size,
        durations => [qw(qn en sn)],
        weights   => [1, 2, 1],
        groups    => [0, 0, 2],
    );
    my $motif = $rr->motif;
    for my $duration (@$motif) {
        $self->midi_msg('note_on', $self->{drums}{snare}{num}, $self->{drums}{snare}{chan}, $self->velo);
        sleep($duration * $self->{per_sec} * 0.9);
        $self->midi_msg('note_off', $self->{drums}{snare}{num}, $self->{drums}{snare}{chan}, 0);
        sleep($duration * $self->{per_sec} * 0.1);
    }
}

sub adjust_groove($self, $i) {
    my @primes = $self->{primes}->@*;
    my $p = $primes[ int rand @primes ];
    $self->{patterns}{hihat} = $self->{r}->euclid($p, $self->{beats});
    if ($self->{N} % 2 == 0) {
        $self->{patterns}{snare}        = $self->{r}->rotate_n(4, $self->{r}->euclid(2, $self->{beats}));
        $self->{patterns}{kick}         = $self->{r}->euclid(2, $self->{beats});
        $self->{patterns}{snare}[$p]    = 1;
        $self->{patterns}{kick}[$p - 1] = 1;
    }
    else {
        $self->{patterns}{snare} = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0];
        $self->{patterns}{kick}  = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1];
    }
    if ($i == 0 and $self->{N} > 0) {
        $self->{patterns}{cymbals}  = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
        $self->{patterns}{hihat}[0] = 0;
    }
    else {
        $self->{patterns}{cymbals} = [ 0 x $self->{beats} ];
    }
    # $self->{drums}{snare}{num}   = $self->random_note;
    # $self->{drums}{kick}{num}    = $self->random_note;
    # $self->{drums}{hihat}{num}   = $self->random_note;
    # $self->{drums}{cymbals}{num} = $self->random_note;
}

sub play($self) {
    try {
        while (1) {
            if ($self->{N} % 2 == 0) {
                my $i;
                for $i (1 .. 3) {
                    $self->part($i);
                }
                if (rand() < 0.5) {
                    $self->fill(4);
                }
                else {
                    $self->part($i, int($self->{beats} / 2));
                    $self->fill(2);
                }
            }
            else {
                for my $i (1 .. 4) {
                    $self->part($i);
                }
            }
            $self->{N} += 1;
        }
    }
    catch {
        $self->stop;
    };
}

sub stop($self) {
    for my $c ($self->{chans}->@*) {
        $self->{outport}->send_event('control_change', $c, 123, 0);
    }
    $self->{outport}->close_port;
    print "\nDrum machine stopped.\n";
}

sub run($self, $name) {
    try {
        $self->{outport} = RtMidiOut->new;
        $self->{outport}->open_virtual_port('RtMidiOut');
        $self->{outport}->open_port_by_name(qr/\Q$name/i);
        print "$self->{outport}\n";
        print "Drum machine running... Ctrl+C to stop.\n";
        $self->play;
    }
    catch {
        print "Run error!\n";
    };
}