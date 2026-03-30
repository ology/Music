#!/usr/bin/env perl

# Play and clock an external MIDI device, like a drum machine or sequencer.
# Examples:
#   perl clocked-euclidean-drums-fills.pl fluid 90
#   perl clocked-euclidean-drums-fills.pl usb 100 -1

use v5.36;
use Data::Dumper::Compact qw(ddc);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use Math::Prime::XS qw(primes);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(dura_size);
use Music::CreatingRhythms ();
use Music::Duration::Partition ();
use Time::HiRes qw(sleep);

my $name = shift || 'usb'; # MIDI sequencer device
my $bpm  = shift || 120; # beats-per-minute
my $chan = shift // 9; # 0-15, 9=percussion, -1=multi-timbral

my $drums = {
    kick  => { num => 36, chan => $chan < 0 ? 0 : $chan, pat => [] },
    snare => { num => 38, chan => $chan < 0 ? 1 : $chan, pat => [] },
    hihat => { num => 42, chan => $chan < 0 ? 2 : $chan, pat => [] },
};

my $notes = [qw(60 64 67)]; # used for random assignment below

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $per_sec = 60 / $bpm;
my $clock_interval = $per_sec / $clocks_per_beat; # seconds / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $beat_interval = $per_sec / $divisions; # 16th-note resolution
my %primes = ( # for computing the pattern
    all  => [ primes($beats) ],
    to_5 => [ primes(5) ],
    to_7 => [ primes(7) ],
);
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?
my $bar_count = 0; # how many measures?
my $toggle = 0; # part A or B?
my $hats = 0; # toggle 1st hihat beat
my $filled = 0; # did we just fill?
my $fill_count = 0;
my @queue; # priority queue for note_on/off messages

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('RtMidiOut');
$midi_out->open_port_by_name(qr/\Q$name/i);

$SIG{INT} = sub { 
    say "\nStop";
    exit;
};

my $mcr = Music::CreatingRhythms->new;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;
        # if ($ticks % $clocks_per_beat == 0) {
            # say "beats: $beat_count";
            # my $size = rand() < 0.4 ? 2 : 4;
            # if ($beat_count % ($divisions - 1) == 0) {
            #     adjust_drums($mcr, $drums, \%primes, \$toggle, 1, \$filled);
            #     if ($beat_count > 0) {
            #         if ($size == 2) {
            #             adjust_drums($mcr, $drums, \%primes, \$toggle, 0, \$filled);
            #         }
            #         adjust_drums($mcr, $drums, \%primes, \$toggle, 1, \$filled);
            #         $filled = 1;
            #     }
            # }
            # adjust_cymbal($drums, \$filled);
            # adjust_drums($mcr, $drums, \%primes, \$toggle, 0, \$filled);
            # $beat_count++;
        # }
        if ($ticks % $sixteenth == 0) {
            if (($beat_count + $beats - 1) % ($beats * $divisions - 1) == 0) {
            # if ($bar_count > 0 && $bar_count % ($divisions - 1) == 0) {
                adjust_drums($mcr, $drums, \%primes, \$toggle, 1, $filled);
                $fill_count++;
                say "x: $beat_count / $bar_count / $fill_count";
            }
            if ($beat_count % ($beats * $divisions) == 0) {
                say "y: $beat_count / $bar_count";
                adjust_drums($mcr, $drums, \%primes, \$toggle, 0, $filled);
            }
            # say ddc $drums;
            for my $drum (keys %$drums) {
                # say $drum, ': '. $drums->{$drum}{pat}[ $beat_count % $beats ];
                if ($drums->{$drum}{pat}[ $beat_count % $beats ]) {
                    push @queue, { drum => $drum, velocity => 127 };
                }
            }
            for my $drum (@queue) {
                $midi_out->note_on($drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, $drum->{velocity});
            }
            # say ddc \@queue;
            $beat_count++;
        }
        else {
            while (my $drum = pop @queue) {
                $midi_out->note_off($drums->{ $drum->{drum} }{chan}, $drums->{ $drum->{drum} }{num}, 0);
            }
        }
        if ($ticks % ($clocks_per_beat * $divisions) == 0) {
            $bar_count++;
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub adjust_cymbal($drums, $filled) {
    if ($$filled) {
        $drums->{crash}{pat}[0] = 1;
        $drums->{hihat}{pat}[0] = 0;
    }
    else {
        $drums->{crash}{pat}[0] = 0;
        $drums->{hihat}{pat}[0] = $hats; # restore bit
    }
    $$filled = 0;
}

sub adjust_drums($mcr, $drums, $primes, $toggle, $fill_flag, $filled) {
    # choose random primes to use by the hihat, kick, and snare
    my ($p, $q, $r) = map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
    if ($fill_flag) {
        say 'fill';
        my %durations = (
            sn => [1],
            en => [1,0],
            qn => [1,0,0,0],
        );
        my $mdp = Music::Duration::Partition->new(
            size    => $divisions,
            pool    => [qw(qn en sn)],
            weights => [1, 2, 1],
            groups  => [0, 0, 2],
        );
        my $motif = $mdp->motif;
        my @convert = map { $durations{$_} } @$motif;
        my @converted;
        for my $list (@convert) {
            for my $bit (@$list) {
                push @converted, $bit;
            }
        }
        $drums->{hihat}{pat} = [ (0) x $beats ];
        $drums->{kick}{pat}  = [ (0) x $beats ];
        $drums->{snare}{pat} = \@converted;
    }
    elsif ($$toggle == 0) {
        say 'part A';
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $drums->{kick}{pat}  = $mcr->euclid($q, $beats);
        $drums->{snare}{pat} = $mcr->rotate_n($r, $mcr->euclid(2, $beats));
        $$toggle = 1; # set to part B
    }
    elsif ($$toggle == 1) {
        say 'part B';
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $drums->{kick}{pat}  = [qw(1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 1)];
        $drums->{snare}{pat} = [qw(0 0 0 0 1 0 0 0 0 0 0 0 1 0 1 0)];
        $$toggle = 0; # set to part A
    }
    $hats = $drums->{hihat}{pat}[0]; # save bit
    # if ($$filled) {
    #     $drums->{cymbals}{pat}  = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    #     $drums->{hihat}{pat}[0] = 0;
    # }
    # else {
    #    $drums->{cymbals}{pat} = [ 0 x $beats ];
    # }
    # $drums->{crash}{num} = random_note($notes);
    # $drums->{snare}{num} = random_note($notes);
    # $drums->{kick}{num}  = random_note($notes);
    # $drums->{hihat}{num} = random_note($notes);
}

sub midi_msg($midi_out, $event, $channel, $note, $velocity) {
    $midi_out->send_event($event, $channel, $note, $velocity);
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

sub random_note($notes) {
    my $random = $notes->[ int rand @$notes ] - 24;
    return $random;
}