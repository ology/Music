#!/usr/bin/env perl

# Multi-timbral generative sequence of tonal phrases and drum beats.
# By default, this program uses the SH-4d for the drums and the
# tones. So have that or something else 4x-timbral running! :)

# Examples:
# verbose, bpm, channels, (program) list, remove, alt_chan:
# perl sh-4d-hop.pl --v --b=90 --l=-1 --r --a=-1
# 2 of 4 channels (default) at a time, changing the group every 8 bars:
# perl sh-4d-hop.pl --verbose --hunk=2 --effect=8
# change the pattern after every full cycle of groups, at random from the first 8:
# perl sh-4d-hop.pl --verbose --quilt=8
# step through specific patterns instead (--quilt is ignored):
# perl sh-4d-hop.pl --verbose --meta='11,23,4'

use v5.40;
use Algorithm::Combinatorics qw(combinations);   # channel hunk groups
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::Util qw(dura_size remove_notes TICKS); # handy
use Music::Duration::Partition ();               # rhythmic phrases
use Music::Scales qw(get_scale_MIDI);            # pitches
use Music::SimpleDrumMachine ();                 # beats
use Music::VoiceGen ();                          # voices

use constant VOLUME_CC => 7; # MIDI channel volume controller

my %opt = (
    drums    => 'SH-4d',      # drum synth name fragment
    alt_chan => 9,            # drum midi channel. -1 means "multi-timbral"
    port     => 'SH-4d',      # tonal synth name fragment
    channels => '1,2,3,4',    # distinct midi channels (0 .. 15)
    list     => -1,           # tone patches (-1 = off)
    bpm      => 70,           # beats-per-minute
    octave   => 2,            # 0 .. 9
    num_oct  => 2,            # number of octaves
    scale    => 'major',      # scale name
    tonic    => 'C',          # scale key base note
    groups   => '',           # allowed durations per channel, like '37=wn,dhn,hn,dqn,qn,en'
    jumps    => '-3,-2,2,3',  # allowed interval jumps
    hunk     => 2,            # how many channels to play simultaneously
    effect   => 4,            # how many bars to hold a hunk before changing it
    quilt    => 128,          # random patterns are drawn from 1 .. quilt (1 .. 128)
    meta     => -1,           # '1,2,3' specific patterns (1 .. 128) or -1 for random
    klang    => 15,           # midi channel that selects the patterns (0 .. 15)
    remove   => 0,            # remove 7th degree notes from scales
    fill     => 0,            # rest tonal notes on the fill bar
    verbose  => 0,
);
GetOptions(\%opt,
    'drums=s',
    'alt_chan=s',
    'port=s',
    'channels=s',
    'list=s',
    'bpm=i',
    'octave=i',
    'num_oct=i',
    'scale=s',
    'tonic=s',
    'groups=s',
    'jumps=s',
    'hunk=i',
    'effect=i',
    'quilt=i',
    'meta=s',
    'klang=i',
    'remove',
    'fill',
    'verbose',
);

# allowed midi channels and program changes
my @channels = map { $_ - 1 } split /\s*,\s*/, $opt{channels};
die "No valid MIDI channels (0 .. 15) given\n" unless @channels;
my @progs = $opt{list} eq '-1' ? () : map { $_ - 1 } split /\s*,\s*/, $opt{list};

# specific patterns to step through (empty means pick them at random)
my @meta = $opt{meta} eq '-1' ? () : split /\s*,\s*/, $opt{meta};
for my $pattern (@meta) {
    die "--meta patterns must be whole numbers 1 .. 128, or -1 for random\n"
        unless $pattern =~ /\A\d+\z/ && $pattern >= 1 && $pattern <= 128;
}
@meta = map { $_ - 1 } @meta;

my %pool;
my @groups = split /;/, $opt{groups};
for my $group (@groups) {
    my ($chan, $durations) = split /=/, $group, 2;
    $pool{ $chan - 1 } = [ split /,/, $durations ];
}

my @jumps = split /\s*,\s*/, $opt{jumps}; # allowed voice intervals

# a "hunk" is how many channels sound at once. The groups played are the
# combinations of the channels of that size. A hunk is held for "effect"
# bars, then the next combination takes over. Once every combination has
# played, the cycle is complete and the next pattern is selected.
die "--hunk must be at least 1\n"   if $opt{hunk} < 1;
die "--effect must be at least 1\n" if $opt{effect} < 1;
die "--quilt must be 1 .. 128\n"    if $opt{quilt} < 1 || $opt{quilt} > 128;
die "--klang must be 0 .. 15\n"     if $opt{klang} < 0 || $opt{klang} > 15;
my $hunk  = $opt{hunk} > @channels ? scalar @channels : $opt{hunk};
my @hunks = combinations(\@channels, $hunk);
my $cycle_bars = @hunks * $opt{effect}; # bars to exhaust all combinations
say 'Hunk size ', $hunk, ' of ', scalar(@channels), ' channels: ',
    scalar(@hunks), ' combinations, changing every ', $opt{effect},
    ' bars. Pattern changes every ', $cycle_bars, ' bars (',
    (@meta ? 'stepping through ' . join(',', map { $_ + 1 } @meta)
           : 'random from 1 .. ' . $opt{quilt}), ')'
    if $opt{verbose};

# we are in 4/4 time...
my $ppqn           = TICKS;                   # internal ticks per quarter-note = 96
my $clock_divider  = $ppqn / 24;              # MIDI clock is always 24 per quarter
my $phrase_ticks   = 4 * $ppqn;               # a phrase is a whole note = 384 ticks
my $clock_interval = 60 / $opt{bpm} / $ppqn;  # seconds per tick
my $ticks          = 0;                       # zero-based clock ticks
my $phrase_count   = 0;                       # phrases (bars) played

my %schedule; # tick => [ [ method, @args ], ... ] of MIDI messages to send

# one independent voice (pitches) and phrase (rhythm) per channel
my %voice;
for my ($i, $ch) (indexed @channels) {
    my @pitches = map {
        get_scale_MIDI($opt{tonic}, $opt{octave} + $i + $_, $opt{scale})
    } 0 .. $opt{num_oct} - 1;
    @pitches = remove_notes([6,14,21], \@pitches)->@* if $opt{remove};
    $voice{$ch} = Music::VoiceGen->new(
        pitches   => \@pitches,
        intervals => \@jumps,
    );
}
my %phrase = map {
    $_ => Music::Duration::Partition->new(
        size => 4, # in quarter-notes
        pool => exists $pool{$_} ? $pool{$_} : [qw(wn dhn hn dqn qn den en sn)],
    )
} @channels;

my $midi_out = open_out($opt{port});
say "Opened '$opt{port}' for tonal MIDI output" if $opt{verbose};

if (@progs) {
    for my ($i, $ch) (indexed @channels) {
        $midi_out->program_change($ch, $progs[ $i % @progs ]);
    }
}

my $loop = IO::Async::Loop->new;

# share loop and clock
my $dm = Music::SimpleDrumMachine->new(
    port_name => $opt{drums},
    bpm       => $opt{bpm},
    chan      => $opt{alt_chan},
    ppqn      => $ppqn,
    loop      => $loop,
    autoplay  => 0,
    virtual   => 0,
    verbose   => $opt{verbose},
);
say "Opened '$opt{drums}' for percussion MIDI output" if $opt{verbose};

my $timer = IO::Async::Timer::Periodic->new(
    interval   => $clock_interval,
    reschedule => 'hard', # anchor to a fixed schedule, don't let tempo drift
    on_tick    => sub {
        # send MIDI clock to both devices
        if ($ticks % $clock_divider == 0) {
            $midi_out->clock;
            $dm->clock;
        }

        $dm->tick; # drums

        # a new phrase every whole note, except while the drums fill
        if ($ticks % $phrase_ticks == 0) {
            my $phrase = $phrase_count++;

            # the pattern changes only when every hunk combination has played
            if ($phrase % $cycle_bars == 0) {
                change_pattern(next_pattern(int($phrase / $cycle_bars)));
            }

            if ($opt{fill} && fill_bar($phrase)) {
                say "$phrase. Resting for the drum fill" if $opt{verbose};
            }
            else {
                trigger_notes($phrase);
            }
        }

        # send everything scheduled for this tick
        if (my $events = delete $schedule{$ticks}) {
            for my $event ($events->@*) {
                my ($method, @args) = $event->@*;
                $midi_out->$method(@args);
            }
        }

        $ticks++;
    },
);

# Graceful ^C:
$loop->watch_signal(INT => sub {
    say "\nStop" if $opt{verbose};
    $timer->stop;
    silence();
    $loop->stop;
});

$timer->start;
$loop->add($timer);
$loop->run;

# choose the (zero-based) pattern for a given cycle: the next --meta entry,
# wrapping around, or a random one that differs from the last
sub next_pattern ($cycle) {
    return $meta[ $cycle % @meta ] if @meta;

    state $last = -1;
    my $pattern;
    do { $pattern = int rand $opt{quilt} }
        while $pattern == $last && $opt{quilt} > 1;
    return $last = $pattern;
}

# select a pattern: zero the tonal volume first, then bank select MSB (85),
# bank select LSB (0), and the program (patch) change
sub change_pattern ($pattern) {
    my $ch = $opt{klang};

    $midi_out->control_change($_, VOLUME_CC, 0) for @channels;

    $midi_out->control_change($ch, 0,  85);
    $midi_out->control_change($ch, 32, 0);
    $midi_out->program_change($ch, $pattern);

    say 'Pattern: ', $pattern + 1 if $opt{verbose};
}

# schedule a phrase for each channel in the current hunk (combination)
sub trigger_notes ($phrase) {
    # the hunk only changes every "effect" bars
    my $index = int($phrase / $opt{effect}) % @hunks;
    my $group = $hunks[$index];

    state $announced = -1;
    if ($opt{verbose} && $announced != $index) {
        say "$phrase. New hunk: ", join(',', map { $_ + 1 } $group->@*);
        $announced = $index;
    }

    for my $ch ($group->@*) {
        my $motif = $phrase{$ch}->motif;
        my $tick  = $ticks;
        for my $duration (@$motif) {
            my $note   = $voice{$ch}->rand;
            my $length = int(dura_size($duration) * $ppqn + 0.5) || 1;
            push    $schedule{$tick}->@*,           [ note_on  => $ch, $note, $dm->velocity ];
            unshift $schedule{$tick + $length}->@*, [ note_off => $ch, $note, 0 ]; # offs first
            $tick += $length;
        }
        say "$phrase. Channel $ch: ", join(' ', @$motif) if $opt{verbose};
    }
}

sub silence {
    %schedule = ();
    $midi_out->panic;
    $dm->stop;
}

sub open_out ($name) {
    my $out = RtMidiOut->new;
    try { $out->open_port_by_name(qr/\Q$name/i) }
    catch ($e) { die "Can't open MIDI port: $name\n" }
    return $out;
}

# The drum machine fills on the last bar of each of its phrases (only
# when filling is on and a phrase is longer than one bar).
sub fill_bar ($phrase) {
    return $dm->filling && $dm->bars > 1 && $phrase % $dm->bars == $dm->bars - 1;
}