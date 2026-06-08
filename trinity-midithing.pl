#!/usr/bin/env perl

# Play an external MIDI device, like a drum machine or sequencer.
# The arguments are verbose-or-not, midi port to play, beats per minute
# Examples:
# perl trinity-midithing.pl --verbose --bpm=70 --drum_port=Trinity --tone_port=MIDIThing2

use v5.36;
use Getopt::Long qw(GetOptions);
use IO::Async::Loop ();
use IO::Async::Timer::Periodic ();
use Math::Prime::XS qw(primes);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(dura_size);
use Music::CreatingRhythms ();
use Music::Duration::Partition ();
use Music::Note ();
use Music::ScaleNote ();
use Time::HiRes qw(sleep);
use YAML::Tiny;

my %opts = (
    verbose    => 0,
    drum_port  => 'Trinity',    # MIDI out drums
    tone_port  => 'MIDIThing2', # MIDI out tones
    rule       => 2,            # Rule number in the list of rules below
    iterations => 4,            # Number of iterations of the fractal curve
    n_duration => 'qn',         # Space separated list of note durations from which to choose *
    r_duration => 'qn',         # Space separated list of rest durations from which to choose *
    midi_note  => 60,           # Initial midinum format note. 60 = Middle C
    offset     => 1,            # +/- Distance to move in the scale for a new note value
    scale      => 'major',      # Name of the scale to traverse
    bpm        => 120,          # Beats per minute of the rendered MIDI
    format     => 'midinum',    # see Music::Note
    fpatch     => 0,            # midi patch number
    gpatch     => 13,           # midi patch number
    # drums => '~/Music/drums.yml', # TODO
);
GetOptions( \%opts,
    'help|?',
    'man',
    'verbose',
    'drum_port=s',
    'tone_port=s',
    'rule=i',
    'iterations=i',
    'n_duration=s',
    'r_duration=s',
    'midi_note=i',
    'offset=i',
    'scale=s',
    'bpm=i',
    'format=s',
    'fpatch=i',
    'gpatch=i',
);

my $drums = {
    kick  => { num => 36, chan => 0 },
    snare => { num => 38, chan => 1 },
    hihat => { num => 42, chan => 2 },
    crash => { num => 49, chan => 3 },
};

# timing parameters
my $divisions = 4; # handy universal divisor
my $clocks_per_beat = 24; # clock ticks per beat
my $per_sec = 60 / $opts{bpm}; # how long is a beat?
my $clock_interval = $per_sec / $clocks_per_beat; # seconds / bpm / ppqn
my $beats = 16; # beats in a phrase
my $beat_interval = $per_sec / $divisions; # 16th-note resolution
my %primes = ( # for syncopated drum patterns
    all  => [primes($beats)],
    to_5 => [primes(5)],
    to_7 => [primes(7)],
);
my $ticks = 0; # clock ticks
my $beat_count = 0; # ...
my $toggle = 0; # part A or B?
my $filled = 0; # did we just fill?
my $hats = 0; # toggle 1st hihat beat

my $midi_out1 = RtMidiOut->new;
my $name = $opts{drum_port};
$midi_out1->open_virtual_port('RtMidiOut_Drums');
$midi_out1->open_port_by_name(qr/\Q$name/i);
say "Sending MIDI to $name" if $opts{verbose};

my $midi_out2 = RtMidiOut->new;
$name = $opts{tone_port};
$midi_out2->open_virtual_port('RtMidiOut_Tonal');
$midi_out2->open_port_by_name(qr/\Q$name/i);
say "Sending MIDI to $name" if $opts{verbose};

$SIG{INT} = sub { 
    say "\nStop" if $opts{verbose};
    exit;
};

my $increment = 0;

my $mcr = Music::CreatingRhythms->new;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $ticks++;
        if ($ticks % $clocks_per_beat == 0) {
            # drums
            my $size = rand() < 0.4 ? 2 : 4;
            if ($beat_count % ($divisions - 1) == 0) {
                adjust_drums($drums, \%primes, \$toggle);
                if ($beat_count > 0) {
                    if ($size == 2) {
                        part($midi_out1, $drums, $beats, $size);
                    }
                    say "Fill size $size" if $opts{verbose};
                    fill($midi_out1, $size);
                    $filled = 1;
                }
            }
            adjust_cymbal($drums, \$filled);
            $increment++;
            if ($opts{verbose}) {
                say "Part $increment";
                say join ',', map { $_ . '=' . join '', $drums->{$_}{pat}->@* } sort keys %$drums;
            }
            part($midi_out1, $drums, $beats, 4);
            $beat_count++;
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub part($midi_out, $drums, $beats, $size) {
    my $end = $size == 2 ? $beats / 2 : $beats;
    for my $i (0 .. $end - 1) {
        my %simul = map { $_ => $drums->{$_}{pat}[$i] } keys %$drums;
        play_simul($midi_out, $beat_interval, $drums, \%simul);
    }
}

sub fill($midi_out, $size) {
    my $mdp = Music::Duration::Partition->new(
        size    => $size,
        pool    => [qw(qn en sn)],
        weights => [1, 2, 1],
        groups  => [0, 0, 2],
    );
    my $motif = $mdp->motif;
    for my $duration (@$motif) {
        midi_msg($midi_out, 'note_on', $drums->{snare}{chan}, $drums->{snare}{num}, velocity(-10, 10, 64));
        sleep(dura_size($duration) * $per_sec * 0.9);
        midi_msg($midi_out, 'note_off', $drums->{snare}{chan}, $drums->{snare}{num}, 0);
        sleep(dura_size($duration) * $per_sec * 0.1);
    }
}

sub play_simul($midi_out, $beat_interval, $drums, $simul) {
    my $i = 0;
    for my $drum (keys %$simul) {
        if ($simul->{$drum} == 1) {
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 127);
        }
        else { # rest
            $midi_out->send_event('note_on', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
        }
    }
    sleep($beat_interval * 0.9);
    $i = 0;
    for my $drum (keys %$simul) {
        $midi_out->send_event('note_off', $drums->{$drum}{chan}, $drums->{$drum}{num}, 0);
    }
    sleep($beat_interval * 0.1);
}

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

sub adjust_drums($drums, $primes, $toggle) {
    my ($p, $q, $r) = map { $primes->{$_}[ int rand $primes->{$_}->@* ] } sort keys %$primes;
    if ($$toggle == 0) { # part A
        $drums->{kick}{pat}  = $mcr->euclid($q, $beats);
        $drums->{snare}{pat} = $mcr->rotate_n($r, $mcr->euclid(2, $beats));
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 1;
    }
    else { # part B
        $drums->{kick}{pat}  = [1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1];
        $drums->{snare}{pat} = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0];
        $drums->{hihat}{pat} = $mcr->euclid($p, $beats);
        $$toggle = 0;
    }
    $hats = $drums->{hihat}{pat}[0]; # save bit
    $drums->{crash}{pat} = [ (0) x $beats ];
}

sub midi_msg($midi_out, $event, $channel, $note, $velocity) {
    $midi_out->send_event($event, $channel, $note, $velocity);
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}
