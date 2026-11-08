#!/usr/bin/env perl

# Play changing parts.

# Examples:
#  perl part-churn-groups.pl # use the defaults
#  perl part-churn-groups.pl --bpm=120 --programs='42,66,67' # play those 3 parts around and around 
#  perl part-churn-groups.pl --bpm=90 --programs=-42 # play 42 different patterns selected at random
#  perl part-churn-groups.pl --bpm=90 --programs=-42 --factor=2 # change patterns twice as fast

use v5.40;
use Array::Circular ();
use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use List::Util qw(shuffle);
use MIDI::RtMidi::Util qw(out_port stop_device stop_all_notes);

my %opt = (
    port     => 'T-8',     # REQUIRED MIDI device (e.g. IAC Bus)
    bpm      => 70,        # beats-per-minute
    channel  => 15,        # nb: the T-8 changes patterns on (zero-based) channel 15
    factor   => 1,         # 1=change on 64 beats, 2=32, 4=16, 8=8 beats...
    programs => '1,2,3,4', # or a negative number of random choices
    size     => 2,         # phrases to repeat
    verbose  => 0,
);
GetOptions(\%opt,
    'port=s',
    'bpm=i',
    'channel=i',
    'factor=i',
    'programs=s',
    'size=i',
    'verbose',
);

die "Open MIDI port name missing\n" unless $opt{port};

my $beats = 16; # beats in a phrase
my $divisions = 4; # divisions of a quarter-note into 16ths
my $clocks_per_beat = 24; # PPQN
my $clock_interval = 60 / $opt{bpm} / $clocks_per_beat; # time / bpm / ppqn
my $sixteenth = $clocks_per_beat / $divisions; # clocks per 16th-note
my $ticks = 0; # clock ticks
my $beat_count = 0; # how many beats?

my $group_num = 0; # program change counter
my @group; # current program changes
my $changes; # array::circular full group
my $changes_inc = 0; # how many changes?

my $device = out_port($opt{port});
try {
  $device->start;
}
catch ($e) {
  die "ERROR: $e\n";
}

if ($opt{programs} =~ /^-\d+$/) { # randomization
  $opt{programs} = join ',', shuffle 1 .. -$opt{programs};
}
my $program = Array::Circular->new(map { $_ - 1 } split /,/, $opt{programs});

@group = draw_group($program, $opt{size});
$changes = Array::Circular->new(@group);
$group_num++;
$changes_inc++;
program_change($device, $opt{channel}, $changes->current);
say "Beat: $beat_count, Program: ", $changes->current, ", Group: $group_num";

my $loop = IO::Async::Loop->new;

$loop->watch_signal(INT => sub {
    say "\nStop";
    stop_device($device);
    stop_all_notes($device);
    $loop->stop;
});

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $device->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            $beat_count++;
            # say '1/16th: ', $beat_count;
            if ($beat_count % ($beats * $divisions / $opt{factor}) == 0) {
              if ($changes_inc >= $opt{size} * 2) {
                @group = draw_group($program, $opt{size});
                $changes = Array::Circular->new(@group);
                $changes_inc = 0;
                $group_num++;
              }
              else {
                $changes->next;
              }
              $changes_inc++;
              program_change($device, $opt{channel}, $changes->current);
              say "Beat: $beat_count, Program: ", $changes->current, ", Group: $group_num";
            }
        }
    },
);

$timer->start;
$loop->add($timer);
$loop->run;

sub draw_group ($pool, $n) {
  my @drawn = $pool->current;
  push @drawn, $pool->next for 2 .. $n;
  $pool->next;
  return @drawn;
}

sub program_change ($device, $chan, $program) {
  try {
    $device->program_change($chan, $program);
  }
  catch ($e) {
    die "ERROR: $e\n";
  }
}