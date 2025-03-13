#!/usr/bin/env perl

# fluidsynth -a coreaudio -m coremidi -g 2.0 ~/Music/FluidR3_GM.sf2
# PERL_FUTURE_DEBUG=1 perl rtmidi-callback.pl

use v5.36;

use curry;
use Array::Circular ();
use Future::IO::Impl::IOAsync;
use List::Util qw(shuffle uniq);
use MIDI::Drummer::Tiny ();
use MIDI::RtController ();
use MIDI::RtController::Filter::Gene ();
use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw(setup_score reverse_dump);
use Music::Duration;
use Number::Closest ();
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

use constant TICKS => 96; # MIDI-Perl default
use constant CHANNEL => 0;
use constant DRUMS   => 9;
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
my $filter_names = shift || '';         # chord,delay,pedal,offset,walk,etc.

my @filter_names = split /\s*,\s*/, $filter_names;

my $rtc = MIDI::RtController->new(
    input  => $input_name,
    output => $output_name,
);
my $rtf = MIDI::RtController::Filter::Gene->new(rtc => $rtc);

my %filter = (
    chord  => sub { add_filters('chord', $rtf->curry::chord_tone, 0) },
    pedal  => sub { add_filters('pedal', $rtf->curry::pedal_tone, 0) },
    delay  => sub { add_filters('delay', $rtf->curry::delay_tone, 0) },
    offset => sub { add_filters('offset', $rtf->curry::offset_tone, 0) },
    walk   => sub { add_filters('walk', $rtf->curry::walk_tone, 0) },
    arp    => sub { add_filters('arp', $rtf->curry::arp_tone, 0) },
    drums  => sub { add_filters('drums', \&drums, 0) },
    score  => sub { add_filters('score', \&score, ['all']) },
);

$filter{$_}->() for @filter_names;

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
my $bpm         = BPM;
my $recording   = 0;
my $playing     = 0;
my $events      = [];
my $quantize    = 0;
my $triplets    = 0;

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $pressed = $self->format_key($key, FORMAT_VIM);
        # say "Got key: $pressed";
        if ($pressed eq '?') { help() }
        elsif ($pressed eq 's') { status() }
        elsif ($pressed eq 'x') { clear() }
        elsif ($pressed eq 'a') { $filter{arp}->()    unless is_member(arp => \@filter_names);    log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'c') { $filter{chord}->()  unless is_member(chord => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'p') { $filter{pedal}->()  unless is_member(pedal => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'd') { $filter{delay}->()  unless is_member(delay => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'o') { $filter{offset}->() unless is_member(offset => \@filter_names); log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'w') { $filter{walk}->()   unless is_member(walk => \@filter_names);   log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'y') { $filter{drums}->()  unless is_member(drums => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed eq 'r') { $filter{score}->()  unless is_member(score => \@filter_names);  log_it(filters => join(', ', @filter_names)) }
        elsif ($pressed =~ /^\d$/) { $rtf->feedback($pressed); log_it(feedback => $rtf->feedback) }
        elsif ($pressed eq '<') { $rtf->delay($rtf->delay - DELAY_INC) unless $rtf->delay <= 0; log_it(delay => $rtf->delay) }
        elsif ($pressed eq '>') { $rtf->delay($rtf->delay + DELAY_INC); log_it(delay => $rtf->delay) }
        elsif ($pressed eq 't') { $arp_type = $arp_types->next; log_it(arp_type => $arp_type) }
        elsif ($pressed eq 'm') { $rtf->scale($scale_names->next); log_it(scale_name => $rtf->scale) }
        elsif ($pressed eq 'u') { $rtf->channel($channels->next); log_it(channel => $rtf->channel) }
        elsif ($pressed eq 'q') { $quantize = $quantize ? 0 : 1; log_it(quantize => $quantize) }
        elsif ($pressed eq 'i') { $triplets = $triplets ? 0 : 1; log_it(triplets => $triplets) }
        elsif ($pressed eq '-') { $direction = $direction ? 0 : 1; log_it(direction => $direction) }
        elsif ($pressed eq '!') { $rtf->offset($rtf->offset + ($direction ? 1 : -1)); log_it(offset => $rtf->offset) }
        elsif ($pressed eq '@') { $rtf->offset($rtf->offset + ($direction ? 2 : -2)); log_it(offset => $rtf->offset) }
        elsif ($pressed eq ')') { $rtf->offset($rtf->offset + ($direction ? 12 : -12)); log_it(offset => $rtf->offset) }
        elsif ($pressed eq '(') { $rtf->offset(0); log_it(offset => $rtf->offset) }
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
    $rtf->channel(CHANNEL);
    @filter_names = ();
    $rtf->arp([]);
    $rtf->arp_type('up');
    $rtf->delay(0.1); # seconds
    $rtf->feedback(1);
    $rtf->offset(OFFSET);
    $direction    = 1; # offset 0=below, 1=above
    $rtf->scale(SCALE);
    $bpm          = BPM;
    $events       = [];
    $quantize     = 0;
    $triplets     = 0;
}

sub status {
    print "\n", join "\n",
        "Filter(s): @filter_names",
        'Channel: ' . $rtf->channel,
        'Pedal-tone: ' . $rtf->pedal,
        'Arp type: ' . $rtf->arp_type,
        'Delay: ' . $rtf->delay,
        'Feedback: ' . $rtf->feedback,
        'Offset distance: ' . $rtf->offset,
        'Offset direction: ' . ($direction ? 'up' : 'down'),
        'Scale name: ' . $rtf->scale,
        "BPM: $bpm",
        "Playing: $playing",
        "Recording: $recording",
        "Quantize: $quantize",
        "Use triplets: $triplets",
    ;
# use Data::Dumper::Compact qw(ddc);
# print "\n", ddc($events);
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
        'r : score recording',
        'x : reset to initial state',
        'q : toggle quantization',
        'i : toggle triplets',
        't : toggle arpeggiation type',
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

sub add_filters ($name, $coderef, $types) {
    $types ||= [qw(note_on note_off)];
    push @filter_names, $name;
    $rtc->add_filter($name, $types, $coderef);
}

#--- FILTERS ---#

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
    )->play_async->retain;
    return 1;
}

sub score ($dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    if ($ev eq 'control_change' && $note == 26 && $vel == 127) { # record
        $recording = 1;
        log_it(recording => 'on');
        my $d = MIDI::Drummer::Tiny->new(
            bpm  => $bpm,
            bars => $feedback,
        );
        my $part = sub {
            my (%args) = @_;
            $args{drummer}->count_in($args{feedback});
        };
        MIDI::RtMidi::ScorePlayer->new(
          device   => $rtc->_midi_out,
          score    => $d->score,
          common   => { drummer => $d, feedback => $feedback },
          parts    => [ $part ],
          sleep    => 0,
          infinite => 0,
        )->play_async->retain;
        $playing = 0;
    }
    elsif ($ev eq 'control_change' && $note == 25 && $vel == 127) { # play
        log_it(recording => 'off');
        $recording = 0;
        if (!$playing && @$events) {
            log_it(playing => 'on');
            $playing = 1;
            my $part = sub {
                my (%args) = @_;
                my $t = $args{bpm} / 60; # beats per second
                for my $i (0 .. $args{events}->$#*) {
                    my $x = 1;
                    if ($i < $args{events}->$#*) {
                        $x = $args{events}->[ $i + 1 ]{dt} * $t;
                    }
                    my $dura;
                    if ($quantize) {
                        my $nc = Number::Closest->new(
                            number  => $x,
                            numbers => [ sort { $a <=> $b } keys $args{lengths}->%* ],
                        );
                        my $closest = $nc->find;
                        $dura = $args{lengths}{$closest};
                    }
                    else {
                        $dura = sprintf 'd%d', $x * TICKS;
                    }
                    log_it(dura => $dura);
                    $args{score}->n($dura, $args{events}[$i]{note});
                }
            };
            my $score = setup_score(lead_in => 0, bpm => $bpm);
            my $lengths = reverse_dump('length');
            %$lengths = map { $_ => $lengths->{$_} } grep { $lengths->{$_} !~ /^t/ } keys %$lengths
                unless $triplets;
            %$lengths = map { $_ => $lengths->{$_} } grep { $lengths->{$_} !~ /[xyz]/ } keys %$lengths; # UGH
            my $common = { score => $score, events => $events, bpm => $bpm, lengths => $lengths };
            MIDI::RtMidi::ScorePlayer->new(
              device   => $rtc->_midi_out,
              score    => $score,
              common   => $common,
              parts    => [ $part ],
              sleep    => 0,
              infinite => 0,
            )->play_async->retain;
            log_it(playing => 'off');
            $playing = 0;
        }
    }
    elsif ($ev eq 'control_change' && $note == 24 && $vel == 127) { # stop
        log_it(recording => 'off');
        log_it(playing => 'off');
        $recording = 0;
        $playing   = 0;
    }

    if ($ev eq 'note_on' && $recording) {
        push @$events, { dt => $dt, note => $note };
    }
    return 0;
}
