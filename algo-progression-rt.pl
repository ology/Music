#!/usr/bin/env perl

=head1 SYNOPSIS

  perl algo-progression-rt --midi_port=synth --bpm=100 --verbose
  perl algo-progression-rt --midi_port=synth --parts='Amv-Amc' \
    --chord_patch=4 --arping --genre=rock --verbose

=head1 DESCRIPTION

Play an endless, ever-changing progression with a randomized
walking bassline and drums, live over a real MIDI port.

Parts are defined as hyphen-phrases of 3 sections:

  <Note><Major|minor><verse|chorus>

Example:

  --parts='DMv-AMv-Bmc-GMc'

While running: press 'p' to pause/resume without closing the MIDI
port, 'r' to restart the progression from the beginning, press 'n'
for a new progression, or 'q' to quit.

=head1 CAVEATS

Rendering a round (calling into Music::Dataset::ChordProgressions,
Music::Bassline::Generator, MIDI::Drummer::Tiny::Grooves, and writing
and re-parsing a MIDI File) briefly blocks this program's single
event loop. With the default C<--pairs=4> a round is many bars long,
so if you hear a stutter when a new round is generated, lower
C<--pairs>.

=cut

use v5.36;
use Data::Dumper::Compact qw(ddc);               # debugging
use File::Temp qw(tempfile);                     # throwaway per-round midi file
use Getopt::Long qw(GetOptions);                 # cli processing
use IO::Async::Loop ();                          # async
use IO::Async::Timer::Periodic ();               # async
use MIDI ();                                     # parse the midi file into events
use MIDI::Drummer::Tiny ();                      # drums
use MIDI::Drummer::Tiny::Grooves ();             # grooves
use MIDI::RtMidi::FFI::Device ();                # rt-midi
use MIDI::RtMidi::Util qw(out_port stop_device); # rt-midi
use MIDI::Util qw(set_chan_patch midi_format ticks);
use Music::Bassline::Generator ();               # bassline
use Music::Chord::Note ();                       # conversion to notes
use Music::Dataset::ChordProgressions qw(as_hash $share_file);
use Music::Duration::Partition ();               # rhythmic phrases
use Music::MelodicDevice::Arpeggiation ();       # arpeggio phrases
use Music::Note ();                              # note format conversion
use Music::Scales qw(get_scale_notes);           # known scale notes
use Term::TermKey::Async qw(FORMAT_VIM);         # keyboard control (pause/quit)

my %opt = (
    midi_port    => 'iac',  # REQUIRED MIDI device (e.g. IAC Bus)
    bpm          => 80,     # beats per minute
    genre        => '',     # a MIDI::Drummer::Tiny::Grooves category like 'rock'
    tonic        => 'A',    # the tonic note for recreating new parts
    allowed      => 'minor', # allowed scale notes for recreating new parts
    parts        => 'DMv-AMv-Bmc-GMc', # the top-level parts
    pairs        => 1,      # the number of pairs of phrases rendered per round
    reps         => 1,      # the number of times to repeat an individual phrase
    multi        => 1,      # the number of times the phrases are repeated
    chord_patch  => 0,      # the MIDI program for the chords part
    bass_patch   => 35,     # the MIDI program for the bass part
    chord_octave => 5,      # the octave of the chords part
    bass_octave  => 2,      # the octave of the bass part
    divisions    => 4,      # the number of divisions in this 4/4 composition
    channel      => 0,      # the MIDI channel the chords part starts on
    arping       => 0,      # are we arpeggiating or not?
    verbose      => 0,
);
GetOptions(\%opt,
    'midi_port=s',
    'bpm=i',
    'genre=s',
    'tonic=s',
    'allowed=s',
    'parts=s',
    'pairs=i',
    'reps=i',
    'multi=i',
    'chord_patch=i',
    'bass_patch=i',
    'chord_octave=i',
    'bass_octave=i',
    'divisions=i',
    'channel=i',
    'arping',
    'verbose',
);

die "Open MIDI port name required for 'midi_port'\n" unless $opt{midi_port};

my @parts = split /-/, $opt{parts};

# Pools for progressive randomization
my @allowed_notes   = get_scale_notes($opt{tonic}, $opt{allowed});
my @scale_qualities = qw(M m); 
my @song_sections   = qw(v c);

# author only - set the local share_file for Music::Dataset::ChordProgressions
$share_file = '/Users/gene/sandbox/Data-Dataset-ChordProgressions/share/Chord-Progressions.csv';

my $chords_channel = $opt{channel};
my $bass_channel   = $opt{channel} + 1;

# static reference data - load once, not on every round
my %progression_data = as_hash();

my $divisions_beat  = 4;                   # divisions of a quarter-note into 16ths
my $clocks_per_beat = 6 * $divisions_beat; # our own engine's PPQN
my $clock_interval  = 60 / $opt{bpm} / $clocks_per_beat;

my @pending; # { note, channel, velocity, on_tick, off_tick }
my @active;  # { note, channel, off_tick }
my $paused  = 0; # toggled by the 'p' key, without tearing down the MIDI port
my $ticks   = 0; # our own clock ticks

my $next_insert_tick      = 0; # where the next round's first event lands
my $regen_threshold_ticks = $divisions_beat * $clocks_per_beat; # keep >= 1 bar buffered

# open the midi device for output
my $midi_out = out_port($opt{midi_port});
$midi_out->start;
say "Started $opt{midi_port}" if $opt{verbose};

$midi_out->program_change($chords_channel, $opt{chord_patch});
$midi_out->program_change($bass_channel,   $opt{bass_patch});
# NOTE: MIDI::Drummer::Tiny sets its own drum channel/patch internally
# inside each round's rendered file, so we don't send one for it here.

$SIG{INT} = \&shutdown_and_exit;

my $loop = IO::Async::Loop->new;

my $timer = IO::Async::Timer::Periodic->new(
    interval => $clock_interval,
    on_tick  => sub {
        $midi_out->clock;
        $ticks++;

        # release any notes whose time is up
        for my $i (reverse 0 .. $#active) {
            if ($ticks >= $active[$i]{off_tick}) {
                $midi_out->note_off($active[$i]{channel}, $active[$i]{note}, 0);
                splice @active, $i, 1;
            }
        }

        # fire any pending notes whose time has come
        my @ready = grep { $ticks >= $_->{on_tick} } @pending;
        @pending  = grep { $ticks <  $_->{on_tick} } @pending;
        for my $p (@ready) {
            $midi_out->note_on($p->{channel}, $p->{note}, $p->{velocity});
            push @active, { note => $p->{note}, channel => $p->{channel}, off_tick => $p->{off_tick} };
        }

        # keep the buffer topped up so playback never runs dry
        if (!$paused && $next_insert_tick - $ticks <= $regen_threshold_ticks) {
            render_and_schedule_round();
        }
    },
);

$timer->start;
$loop->add($timer);

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $keystr = $self->format_key($key, FORMAT_VIM);

        if ($keystr eq 'p' || $keystr eq 'Space') {
            toggle_pause();
        }
        elsif ($keystr eq 'n') {
            make_new_progression();
            restart_performance();
        }
        elsif ($keystr eq 'r') {
            restart_performance();
        }
        elsif ($keystr eq 'q' || $keystr eq 'C-c' || $keystr eq 'Escape') {
            shutdown_and_exit();
        }
    },
);
$loop->add($tka);

say "Press 'p' to pause/resume, 'r' to restart, 'q' to quit" if $opt{verbose};

# prime the buffer with the first round before the clock has anything to play
render_and_schedule_round();

$loop->run;

# One "round" = one full pass through --parts, --pairs times,
# rendered by the *unmodified* offline generator subs into a
# throwaway MIDI File, which is then parsed back and appended onto
# the live clock schedule.
sub render_and_schedule_round {
    my (undef, $filename) = tempfile(SUFFIX => '.mid', UNLINK => 0);

    my $d = MIDI::Drummer::Tiny->new(
        file   => $filename,
        bpm    => $opt{bpm},
        bars   => $opt{divisions} * @parts * $opt{reps} * $opt{pairs},
        reverb => 10,
    );

    my @progressions;

    $d->sync(
        sub { drums($d) },
        sub { arp_chords($d, \@progressions, \%progression_data) },
        sub { bass($d, \@progressions) },
    );

    $d->write;

    schedule_midi($filename);

    unlink $filename;
}

sub schedule_midi {
    my ($filename) = @_;

    my $opus              = MIDI::Opus->new({ from_file => $filename });
    my $midi_ticks_per_qn = $opus->ticks; # the rendered file's own PPQN
    my $scale             = $clocks_per_beat / $midi_ticks_per_qn; # our engine's ticks

    my $round_start_tick = $next_insert_tick;
    my $round_end_tick   = $round_start_tick;

    for my $track ($opus->tracks) {
        my $abs_time = 0;
        my %open_notes; # "channel-note" => { on_time, velocity }, to pair on/off events

        for my $event ($track->events) {
            my ($type, $delta, @rest) = @$event;
            $abs_time += $delta;

            if ($type eq 'note_on' && $rest[2] > 0) {
                my ($channel, $note, $velocity) = @rest;
                $open_notes{"$channel-$note"} = { on_time => $abs_time, velocity => $velocity };
            }
            elsif ($type eq 'note_off' || ($type eq 'note_on' && $rest[2] == 0)) {
                my ($channel, $note) = @rest;
                my $on = delete $open_notes{"$channel-$note"};
                next unless $on;

                my $on_tick  = $round_start_tick + int($on->{on_time} * $scale);
                my $off_tick = $round_start_tick + int($abs_time     * $scale);
                $off_tick    = $on_tick + 1 if $off_tick <= $on_tick;

                push @pending, {
                    note     => $note,
                    channel  => $channel,
                    velocity => $on->{velocity},
                    on_tick  => $on_tick,
                    off_tick => $off_tick,
                };

                $round_end_tick = $off_tick if $off_tick > $round_end_tick;
            }
        }
    }

    $next_insert_tick = $round_end_tick;
}

sub toggle_pause {
    $paused = !$paused;

    if ($paused) {
        $timer->stop; # clock ticks freeze here

        # silence anything currently sounding so nothing gets stuck on
        for my $n (@active) {
            $midi_out->note_off($n->{channel}, $n->{note}, 0);
        }
        @active = ();

        say "\n-- Paused --" if $opt{verbose};
    }
    else {
        $timer->start; # resumes from the same $ticks count, port stays open throughout
        say "-- Resumed --" if $opt{verbose};
    }
}

sub make_new_progression {
    my $num_sections = scalar(@parts) || 4;
    my @new_parts;

    for (1 .. $num_sections) {
        my $random_note    = $allowed_notes[int rand @allowed_notes];
        my $random_quality = $scale_qualities[int rand @scale_qualities];
        my $random_section = $song_sections[int rand @song_sections];

        push @new_parts, "$random_note$random_quality$random_section";
    }

    @parts = @new_parts;

    if ($opt{verbose}) {
        say "\nGenerated New Parts: " . join('-', @parts);
    }
}

sub restart_performance {
    # silence anything currently sounding so nothing gets stuck on
    for my $n (@active) {
        $midi_out->note_off($n->{channel}, $n->{note}, 0);
    }
    @active  = ();
    @pending = (); # drop the rest of the currently-buffered round too

    # $next_insert_tick = $ticks; # anchor the fresh round to right now, not the old buffer's tail
    # cushion the scheduling line slightly to safely avoid CPU clock race conditions
    $next_insert_tick = $ticks + 2;

    say "\n-- Restarting --" if $opt{verbose};

    render_and_schedule_round(); # arp_chords() always starts back at part 1 within a round
}

sub shutdown_and_exit {
    say "\nStop" if $opt{verbose};
    stop_device($midi_out);
    exit;
}

sub drums ($d) {
    my $grooves = MIDI::Drummer::Tiny::Grooves->new(
        drummer    => $d,
        share_file => '/Users/gene/sandbox/MIDI-Drummer-Tiny/share/drum-pattern-bit-strings.txt', # author only
    );
    my $set;
    if ($opt{genre}) {
        $set = $grooves->search({ cat => $opt{genre} });
    }
    else {
        $set = $grooves->all_grooves;
    }
    my @keys = keys %$set;

    my ($groove, $g);

    for my $i (1 .. $opt{multi} * $d->bars + ($opt{divisions} - 1)) {
        if ($i % 4 == 0) {
            $groove = $set->{ $keys[rand @keys] };
            $g = $groove->{groove};
            $g = $grooves->swap_pat($g, 'crash', 'closed'); # too much crashing - ugh
        }
        $grooves->groove($g);
    }
}

sub arp_chords ($d, $progressions, $data) {
    set_chan_patch($d->score, $chords_channel, $opt{chord_patch});

    my $cn = Music::Chord::Note->new;

    my $arp = Music::MelodicDevice::Arpeggiation->new(verbose => 1);
    my @types = keys $arp->arp_type->%*;

    my @accum; # note accumulator

    my $p = 1; # part number
    my $q = 1; # duration accumulator

    for my $part ( map { @parts } 1 .. $opt{pairs}) {
        my ($note, $section, $scale, $pool);
        # Set the pool of possible progressions given scale and section
        if ($part =~ /^([A-G][#b]?)(M|m)(v|c)$/) {
            ($note, $scale, $section) = ($1, $2, $3);
            $scale   = $scale eq 'M' ? 'major' : 'minor';
            $section = $section eq 'v' ? 'verse' : 'chorus';
            $pool    = $data->{rock}{$scale}{$section};
        }

        # Set the transposition map
        my %note_map;
        @note_map{ get_scale_notes('C', $scale) } = get_scale_notes($note, $scale);

        # Get a random progression
        my $progression = $pool->[int rand @$pool];

        # Transpose the progression chords from C
        (my $named = $progression->[0]) =~ s/([A-G][#b]?)/$note_map{$1}/g;

        # Keep track of the progressions used
        push @$progressions, $named;

        print "$p. $note $scale: $named, $progression->[1]\n";

        my @chords = split /-/, $named;

        # Add each chord to the score
        for my $j (1 .. $opt{reps}) {
            for my $chord (@chords) {
                $chord =~ s/sus2/add9/;
                $chord =~ s/6sus4/sus4/;
                my @notes = $cn->chord_with_octave($chord, $opt{chord_octave});
                @notes = midi_format(@notes);
                print "N: @notes\n" if $opt{verbose};
                if ($opt{arping} && $p % 2 == 0) {
                    my $nums = [];
                    push @$nums, Music::Note->new($_, 'ISO')->format('midinum')
                        for @notes;
                    my $arped = $arp->arp($nums, $q % 2 == 0 ? 1 : 4, $types[int rand @types]);
                    push @accum, $arped;
                    $q++;
                }
                else {
                    push @accum, \@notes;
                }
            }
        }
        $p++;
    }
    for my $j (1 .. $opt{multi}) {
        for my $n (@accum) {
            if (ref $n->[0] eq 'ARRAY') {
                my $duration = 0;
                for my $j (@$n) {
                    $d->note(@$j);
                    if ($j->[0] =~ /^d(\d+)$/) {
                        $duration += $1;
                    }
                }
                my $rest = $opt{divisions} * ticks($d->score) - $duration;
                $d->rest('d' . $rest) if $rest > 0;
            }
            else {
                $d->note($d->whole, @$n);
            }
        }
    }
}

sub bass ($d, $progressions) {
    set_chan_patch($d->score, $bass_channel, $opt{bass_patch});

    my $mdp = Music::Duration::Partition->new(
        size    => $opt{divisions},
        pool    => [qw/ dhn hn qn /],
        weights => [    1,  2, 3   ],
    );
    my @motifs = $mdp->motifs(4);

    my $bassline = Music::Bassline::Generator->new(
        octave  => $opt{bass_octave},
        guitar  => 1,
        scale   => sub { $_[0] =~ /^[A-G][#b]?m/ ? 'pminor' : 'pentatonic' },
        verbose => $opt{verbose},
    );

    for (1 .. $opt{reps} * $opt{multi}) {
        for my $p (@$progressions) {
            my @chords = split /-/, $p;

            my $i = 0;

            for my $chord (@chords) {
                $chord =~ s/6sus4/sus4/;

                my $m = $motifs[int rand @motifs];

                my $notes = $bassline->generate($chord, scalar(@$m));

                $mdp->add_to_score($d->score, $m, $notes);

                $i++;
            }
        }
    }
}