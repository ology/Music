#!/usr/bin/env perl

# XXX THIS IS BROKEN NOW> :(

# Play an external MIDI device, like a drum machine or sequencer.
# The arguments are verbose-or-not, midi port to play, beats per minute
# Examples:
# perl trinity-midithing.pl --verbose --bpm=70 --port=Trinity

use v5.36;
use feature 'try';
use Array::Circular ();
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
    port       => 'Trinity',    # MIDI out drums
    rule       => 6,            # Rule number in the list of rules below
    iterations => 2,            # Number of iterations of the fractal curve
    n_duration => 'qn',         # Space separated list of note durations from which to choose *
    r_duration => 'qn',         # Space separated list of rest durations from which to choose *
    midi_note  => 60,           # Initial midinum format note. 60 = Middle C
    offset     => 1,            # +/- Distance to move in the scale for a new note value
    scale      => 'major',      # Name of the scale to traverse
    bpm        => 120,          # Beats per minute of the rendered MIDI
    format     => 'midinum',    # see Music::Note
    fpatch     => 4,            # midi patch number
    gpatch     => 13,           # midi patch number
    # drums => '~/Music/drums.yml', # TODO
);
GetOptions( \%opts,
    'help|?',
    'man',
    'verbose',
    'port=s',
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
    kick  => { num => 36, chan => 0, vel => 0 },
    snare => { num => 38, chan => 1, vel => 0 },
    hihat => { num => 42, chan => 2, vel => 0 },
    crash => { num => 49, chan => 3, vel => 0 },
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

my $midi_out = RtMidiOut->new;
my $name = $opts{port};
$midi_out->open_virtual_port('RtMidiOut_Drums');
try {
    $midi_out->open_port_by_name(qr/\Q$name/i);
}
catch ($e) {
    die "Can't open MIDI port: $name";
}
say "Sending MIDI to $name" if $opts{verbose};

# Split the durations into a list so that they can be randomly selected
my $n_duration = [ split /\s+/, $opts{n_duration} ];
my $r_duration = [ split /\s+/, $opts{r_duration} ];
# The master list of fractals by rule number, their axioms and production rules
my $yaml_text = do { local $/; <DATA> };
my $rules = YAML::Tiny->read_string($yaml_text)->[0];
# print ddc $rules;
my $midi_note = $opts{midi_note};
# Get the axiom to use based on the given rule
my $string = $rules->{ $opts{rule} }{axiom};
# Create a note object for the given start note value
my $note = Music::Note->new( $midi_note, $opts{format} );
# Create a scale-note object to use to traverse the given scale
my $msn = Music::ScaleNote->new(
    scale_note => $note->format('isobase'),
    scale_name => $opts{scale},
    verbose    => 1,
);
# The dispatch table of MIDI routines based on "turtle graphic" moves
my %translate = (
    # Add a rest to the score
    'f' => sub { return 0, $midi_note, 0 }, # channel, note, velocity
    'g' => sub { return 1, $midi_note, 0 }, # ""
    # Add a note to the score
    'F' => sub { return 0, $midi_note, 127 },
    'G' => sub { return 1, $midi_note, 127 },
    # Decrement the scale-note
    '-' => sub {
        $midi_note = $msn->get_offset(
            note_name   => $midi_note,
            note_format => $opts{format},
            offset      => -$opts{offset},
        )->format( $opts{format} );
        return undef, undef, undef;
    },
    # Increment the scale-note
    '+' => sub {
        $midi_note = $msn->get_offset(
            note_name   => $midi_note,
            note_format => $opts{format},
            offset      => $opts{offset},
        )->format( $opts{format} );
        return undef, undef, undef;
    },
);

$SIG{INT} = sub { 
    say "\nStop" if $opts{verbose};
    try {
        $midi_out->stop;
        $midi_out->panic;
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n";
    }
    exit;
};

# Apply the string re-writing production rules
for ( 1 .. $opts{iterations} ) {
    $string =~ s/(.)/defined($rules->{ $opts{rule} }{$1}) ? $rules->{ $opts{rule} }{$1} : $1/eg;
}
say "L-system:\n$string" if $opts{verbose};
my $circular_string = Array::Circular->new(split //, $string);

my $increment = 0;

my $mcr = Music::CreatingRhythms->new;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $ticks++;
        my $duration = 'qn';
        if ($ticks % $clocks_per_beat == 0) {
            # execute the dispatch routine defined by the string items
            my ($item, @rtn);
            do {
                $item = $circular_string->next;
                say "Item: $item";
                @rtn = $translate{$item}->() if exists $translate{$item};
            } until ($item =~ /[fg]/i);
            say "$item : @rtn";
            midi_msg($midi_out, 'note_on', @rtn);
            sleep(dura_size($duration) * $per_sec * 0.9);
            midi_msg($midi_out, 'note_off', $rtn[0], $rtn[1], 0);
            sleep(dura_size($duration) * $per_sec * 0.1);
        }
    },
);
$timer->start;

$loop->add($timer);
$loop->run;

sub midi_msg($midi_out, $event, $channel, $note, $velocity) {
    $midi_out->send_event($event, $channel, $note, $velocity);
}

sub velocity($min, $max, $offset) {
    my $random = $offset + int(rand($max - $min + 1)) + $min;
    return $random;
}

__DATA__
1:
  name: 'Branches'
  axiom: 'X'
  X: 'YF-X+X'
  Y: 'F'
2:
  name: 'Koch curve'
  axiom: 'F'
  F: 'F+F-F-F+F'
3:
  name: 'Fractal plant'
  axiom: 'X'
  X: 'F-XXF-X+FX'
  F: 'FF'
4:
  name: 'Dragon curve'
  axiom: 'FX'
  X: 'X+YF+'
  Y: '-FX-Y'
5:
  name: 'Sierpiński arrowhead curve'
  axiom: 'F'
  F: 'G-F-G'
  G: 'F+G+F'
6:
  name: 'Sierpiński triangle'
  axiom: 'F-G-G'
  F: 'F-G+F+G-F'
  G: 'GG'
7:
  name: 'Koch snowflake'
  axiom: 'F++F++F'
  F: 'F-F++F-F'
  X: 'FF'
8:
  name: 'Sierpiński carpet'
  axiom: 'F'
  F: 'F+F-F-F-G+F+F+F-F'
  G: 'GGG'
9:
  name: 'Koch island'
  axiom: 'F-F-F-F'
  F: 'F-F+F+FF-F-F+F'
10:
  name: 'Koch islands and lakes'
  axiom: 'F+F+F+F'
  F: 'F+f-FF+F+FF+Ff+FF-f+FF-F-FF-Ff-FFF'
  f: 'ffffff'
11:
  name: 'Grid'
  axiom: 'F-F-F-F'
  F: 'FF-F-F-F-FF'
12:
  name: 'Terndrils'
  axiom: 'F-F-F-F'
  F: 'FF-F--F-F'
13:
  name: 'Custom'
  axiom: 'F+G-F+G'
  F: 'FG+F--F+F'
14:
  name: 'Branches with space'
  axiom: 'X'
  X: 'YF-X+X'
  Y: 'f'
15:
  name: 'Leaf'
  axiom: 'X'
  X: 'F[+X][-X]FX'
  F: 'FF'