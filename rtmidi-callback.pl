#!/usr/bin/env perl

# fluidsynth -a coreaudio -m coremidi -g 2.0 ~/Music/FluidR3_GM.sf2
# PERL_FUTURE_DEBUG=1 perl rtmidi-callback.pl

use v5.36;

use Array::Circular ();
use Future::IO::Impl::IOAsync;
use List::SomeUtils qw(first_index);
use List::Util qw(shuffle uniq);
use MIDI::Drummer::Tiny ();
use MIDI::RtController ();
use MIDI::RtMidi::ScorePlayer ();
use Music::Chord::Note ();
use Music::Note ();
use Music::ToRoman ();
use Music::Scales qw(get_scale_MIDI get_scale_notes);
use Music::VoiceGen ();
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

use constant CHANNEL => 0;
use constant DRUMS   => 9;
# for the pedal-tone filter:
use constant PEDAL => 55; # G below middle C
# for the pedal-tone, delay and arp filters:
use constant DELAY_INC => 0.01;
use constant VELO_INC  => 10; # volume change offset
# for the modal chord filter:
use constant NOTE  => 'C';     # key
use constant SCALE => 'major'; # mode
# for the offset filter:
use constant OFFSET => -12; # octave below
use constant BPM => 120; # beats per minute

my $input_name   = shift || 'tempopad'; # midi controller device
my $output_name  = shift || 'fluid';    # fluidsynth output
my $filter_names = shift || '';         # chord,delay,pedal,offset,walk

my @filter_names = split /\s*,\s*/, $filter_names;

my %filter = (
    chord  => sub { add_filters(chord  => \&chord_tone) },
    pedal  => sub { add_filters(pedal  => \&pedal_tone) },
    delay  => sub { add_filters(delay  => \&delay_tone) },
    arp    => sub { add_filters(arp    => \&arp_tone) },
    offset => sub { add_filters(offset => \&offset_tone) },
    walk   => sub { add_filters(walk   => \&walk_tone) },
    drums  => sub { add_filters(drums  => \&drums) },
);

$filter{$_}->() for @filter_names;

my $channel     = CHANNEL;
my $channels    = Array::Circular->new(SCALE, DRUMS);
my $arp         = [];
my $arp_types   = Array::Circular->new(qw/up down random/);
my $arp_type    = 'up';
my $delay       = 0.1; # seconds
my $feedback    = 1;
my $offset      = OFFSET;
my $direction   = 1; # offset 0=below, 1=above
my $scale_name  = SCALE;
my $scale_names = Array::Circular->new(SCALE, 'minor');
my $bpm        = BPM;

my $rtc = MIDI::RtController->new(
    input  => $input_name,
    output => $output_name,
);

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $pressed = $self->format_key($key, FORMAT_VIM);
        # say "Got key: $pressed";
        if ($pressed eq '?') { help() }
        elsif ($pressed eq 's') { status() }
        elsif ($pressed eq 'x') { clear() }
        elsif ($pressed =~ /^\d$/) { $feedback = $pressed; log_it(feedback => $feedback) }
        elsif ($pressed eq '<') { $delay -= DELAY_INC unless $delay <= 0; log_it(delay => $delay) }
        elsif ($pressed eq '>') { $delay += DELAY_INC; log_it(delay => $delay) }
        elsif ($pressed eq 'a') { $filter{arp}->()    unless is_member(arp => \@filter_names);    log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'c') { $filter{chord}->()  unless is_member(chord => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'p') { $filter{pedal}->()  unless is_member(pedal => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'd') { $filter{delay}->()  unless is_member(delay => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'o') { $filter{offset}->() unless is_member(offset => \@filter_names); log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'w') { $filter{walk}->()   unless is_member(walk => \@filter_names);   log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'y') { $filter{drums}->()  unless is_member(drums => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'r') { $arp_type = $arp_types->next; log_it(arp_type => $arp_type) }
        elsif ($pressed eq 'm') { $scale_name = $scale_names->next; log_it(scale_name => $scale_name) }
        elsif ($pressed eq 'u') { $channel = $channels->next; log_it(channel => $channel) }
        elsif ($pressed eq '-') { $direction = $direction ? 0 : 1; log_it(direction => $direction) }
        elsif ($pressed eq '!') { $offset += $direction ? 1  : -1;  log_it(offset => $offset) }
        elsif ($pressed eq '@') { $offset += $direction ? 2  : -2;  log_it(offset => $offset) }
        elsif ($pressed eq ')') { $offset += $direction ? 12 : -12; log_it(offset => $offset) }
        elsif ($pressed eq '(') { $offset = 0; log_it(offset => $offset) }
        elsif ($pressed eq ',') { $bpm += $direction ? 1  : -1;  log_it(bpm => $bpm) }
        elsif ($pressed eq '.') { $bpm += $direction ? 2  : -2;  log_it(bpm => $bpm) }
        elsif ($pressed eq '/') { $bpm += $direction ? 10 : -10; log_it(bpm => $bpm) }
        $rtc->loop->loop_stop if $key->type_is_unicode and
                                 $key->utf8 eq 'C' and
                                 $key->modifiers & KEYMOD_CTRL;
    },
);
$rtc->loop->add($tka);

$rtc->run;

sub log_it ($name, $value) {
    print "$name => $value\n";
}

sub is_member ($name, $items) {
    return grep { $name eq $_ } @$items;
}

sub clear {
    $rtc->filters({});
    $channel      = CHANNEL;
    @filter_names = ();
    $arp          = [];
    $arp_type     = 'up';
    $delay        = 0.1; # seconds
    $feedback     = 1;
    $offset       = OFFSET;
    $direction    = 1; # offset 0=below, 1=above
    $scale_name   = SCALE;
    $bpm          = BPM;
}

sub status {
    print join "\n",
        "Filter(s): @filter_names",
        "Channel: $channel",
        'Pedal-tone: ' . PEDAL,
        "Arp type: $arp_type",
        "Delay: $delay",
        "Feedback: $feedback",
        "Offset distance: $offset",
        'Offset direction: ' . ($direction ? 'up' : 'down'),
        "Scale name: $scale_name",
        "BPM: $bpm",
    ;
    print "\n\n";
}

sub help {
    print join "\n",
        '? : show this program help!',
        's : show the program state',
        'u : toggle the drum channel',
        '0-9 : set the feedback',
        '< : delay decrement by ' . DELAY_INC,
        '> : delay increment by ' . DELAY_INC,
        'a : arpeggiate filter',
        'c : modal chord filter',
        'p : pedal-tone filter',
        'd : delay filter',
        'o : offset filter',
        'w : walk filter',
        'y : drums filter',
        'x : reset to initial state',
        'r : toggle arpeggiation type',
        'm : toggle major/minor',
        '- : toggle offset direction',
        '! : increment or decrement the offset by 1',
        '@ : increment or decrement the offset by 2',
        ') : increment or decrement the offset by 12',
        '( : set the offset to 0',
        '. : increment or decrement the BPM by 1',
        '. : increment or decrement the BPM by 2',
        '/ : increment or decrement the BPM by 10',
        'Ctrl+C : stop the program',
    ;
    print "\n\n";
}

sub add_filters ($name, $coderef) {
    push @filter_names, $name;
    $rtc->add_filter($name, $_ => $coderef)
        for qw(note_on note_off);
}

#--- FILTERS ---#

sub chord_notes ($note) {
    my $mn = Music::Note->new($note, 'midinum');
    my $base = uc($mn->format('isobase'));
    my @scale = get_scale_notes(NOTE, SCALE);
    my $index = first_index { $_ eq $base } @scale;
    return $note if $index == -1;
    my $mtr = Music::ToRoman->new(scale_note => $base);
    my @chords = $mtr->get_scale_chords;
    my $chord = $scale[$index] . $chords[$index];
    my $cn = Music::Chord::Note->new;
    my @notes = $cn->chord_with_octave($chord, $mn->octave);
    @notes = map { Music::Note->new($_, 'ISO')->format('midinum') } @notes;
    return @notes;
}
sub chord_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = chord_notes($note);
    $rtc->send_it([ $ev, $channel, $_, $vel ]) for @notes;
    return 0;
}

sub pedal_notes ($note) {
    return PEDAL, $note, $note + 7;
}
sub pedal_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = pedal_notes($note);
    my $delay_time = 0;
    for my $n (@notes) {
        $delay_time += $delay;
        $rtc->delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
    }
    return 0;
}

sub delay_notes ($note) {
    return ($note) x $feedback;
}
sub delay_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = delay_notes($note);
    my $delay_time = 0;
    for my $n (@notes) {
        $delay_time += $delay;
        $rtc->delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
        $vel -= VELO_INC;
    }
    return 0;
}

sub arp_notes ($note) {
    $feedback = 2 if $feedback < 2;;
    if (@$arp >= 2 * $feedback) { # double, on/off note event
        shift @$arp;
        shift @$arp;
    }
    push @$arp, $note;
    my @notes = uniq @$arp;
    if ($arp_type eq 'up') {
        @notes = sort { $a <=> $b } @notes;
    }
    elsif ($arp_type eq 'down') {
        @notes = sort { $b <=> $a } @notes;
    }
    elsif ($arp_type eq 'random') {
        @notes = shuffle @notes;
    }
    return @notes;
}
sub arp_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = arp_notes($note);
    my $delay_time = 0;
    for my $n (@notes) {
        $rtc->delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
        $delay_time += $delay;
    }
    return 1;
}

sub offset_notes ($note) {
    my @notes = ($note);
    push @notes, $note + $offset if $offset;
    return @notes;
}
sub offset_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = offset_notes($note);
    $rtc->send_it([ $ev, $channel, $_, $vel ]) for @notes;
    return 0;
}

sub walk_notes ($note) {
    my $mn = Music::Note->new($note, 'midinum');
    my @pitches = (
        get_scale_MIDI(NOTE, $mn->octave, $scale_name),
        get_scale_MIDI(NOTE, $mn->octave + 1, $scale_name),
    );
    my @intervals = qw(-3 -2 -1 1 2 3);
    my $voice = Music::VoiceGen->new(
        pitches   => \@pitches,
        intervals => \@intervals,
    );
    return map { $voice->rand } 1 .. $feedback;
}
sub walk_tone ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    my @notes = walk_notes($note);
    my $delay_time = 0;
    for my $n (@notes) {
        $delay_time += $delay;
        $rtc->delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
    }
    return 0;
}

sub drum_parts ($note) {
    my $part;
    if ($note == 99) {
        $part = sub {
            my (%args) = @_;
            $args{drummer}->metronome4;
        };
    }
    else {
        $part = sub {
            my (%args) = @_;
            $args{drummer}->note($args{drummer}->sixtyfourth, $note);
        };
    }
    return $part;
}
sub drums ($dt, $event) {
    print "Event: @$event\n" if $rtc->verbose;
    my ($ev, $chan, $note, $vel) = $event->@*;
    return 1 unless $ev eq 'note_on';
    my $part = drum_parts($note);
    my $d = MIDI::Drummer::Tiny->new(
        bpm  => $bpm,
        bars => $feedback,
    );
    MIDI::RtMidi::ScorePlayer->new(
      device   => $rtc->_midi_out,
      score    => $d->score,
      common   => { drummer => $d },
      parts    => [ $part ],
      sleep    => 0,
      infinite => 0,
      # dump     => 1,
    )->play_async->retain;
    return 1;
}
