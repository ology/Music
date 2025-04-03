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
use MIDI::RtController::Filter::Drums ();
use MIDI::RtController::Filter::Math ();
use MIDI::RtController::Filter::Tonal ();
use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw(setup_score reverse_dump);
use Music::Duration;
use Number::Closest ();
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

use constant TICKS     => 96; # MIDI-Perl default
use constant CHANNEL   => 0;
use constant DRUMS     => 9;
use constant DELAY_INC => 0.01;
use constant SCALE     => 'major'; # mode
use constant OFFSET    => -12; # octave below
use constant BPM       => 120; # beats per minute

my $input_name   = shift || 'tempopad'; # midi controller device
my $output_name  = shift || 'fluid';    # fluidsynth output
my $filter_names = shift || '';         # chord,delay,pedal,offset,walk,etc.

my @filter_names = split /\s*,\s*/, $filter_names;

my $rtc = MIDI::RtController->new(
    input  => $input_name,
    output => $output_name,
);
my $rtfd = MIDI::RtController::Filter::Drums->new(rtc => $rtc);
my $rtfm = MIDI::RtController::Filter::Math->new(rtc => $rtc);
my $rtft = MIDI::RtController::Filter::Tonal->new(rtc => $rtc);

my %filter = (
    chord  => sub { add_filters('chord', $rtft->curry::chord_tone, 0) },
    pedal  => sub { add_filters('pedal', $rtft->curry::pedal_tone, 0) },
    delay  => sub { add_filters('delay', $rtft->curry::delay_tone, 0) },
    offset => sub { add_filters('offset', $rtft->curry::offset_tone, 0) },
    walk   => sub { add_filters('walk', $rtft->curry::walk_tone, 0) },
    arp    => sub { add_filters('arp', $rtft->curry::arp_tone, 0) },
    stairs => sub { add_filters('stairs', $rtfm->curry::stair_step, 0) },
    drums  => sub { add_filters('drums', $rtfd->curry::drums, 0) },
    score  => sub { add_filters('score', \&score, ['all']) },
    cc     => sub { add_filters('cc', \&cc, ['all']) },
);

$filter{$_}->() for @filter_names;

my $channels  = Array::Circular->new(CHANNEL, DRUMS);
my $scales    = Array::Circular->new(SCALE, 'minor');
my $direction = 1; # offset 0=below, 1=above
my $recording = 0;
my $playing   = 0;
my $quantize  = 0;
my $triplets  = 0;
my $events    = [];

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $pressed = $self->format_key($key, FORMAT_VIM);
        # say "Got key: $pressed";
        if ($pressed =~ /^\d$/) { feedback($pressed) }
        elsif ($pressed eq '?') { help() }
        elsif ($pressed eq 's') { status() }
        elsif ($pressed eq 'x') { clear() }
        elsif ($pressed eq 'a') { engage('arp') }
        elsif ($pressed eq 'c') { engage('chord') }
        elsif ($pressed eq 'p') { engage('pedal') }
        elsif ($pressed eq 'd') { engage('delay') }
        elsif ($pressed eq 'o') { engage('offset') }
        elsif ($pressed eq 'w') { engage('walk') }
        elsif ($pressed eq 'z') { engage('stairs') }
        elsif ($pressed eq 'y') { engage('drums') }
        elsif ($pressed eq 'r') { engage('score') }
        elsif ($pressed eq '#') { engage('cc') }
        elsif ($pressed eq '<') { delay($pressed) }
        elsif ($pressed eq '>') { delay($pressed) }
        elsif ($pressed eq 'u') { channel() }
        elsif ($pressed eq 't') { $rtft->arp_type($rtft->arp_types->next); log_it(arp_type => $rtft->arp_type) }
        elsif ($pressed eq 'm') { $rtft->scale($scales->next); log_it(scales => $rtft->scale) }
        elsif ($pressed eq '!') { $rtft->offset($rtft->offset + ($direction ? 1 : -1)); log_it(offset => $rtft->offset) }
        elsif ($pressed eq '@') { $rtft->offset($rtft->offset + ($direction ? 2 : -2)); log_it(offset => $rtft->offset) }
        elsif ($pressed eq ')') { $rtft->offset($rtft->offset + ($direction ? 12 : -12)); log_it(offset => $rtft->offset) }
        elsif ($pressed eq '(') { $rtft->offset(0); log_it(offset => $rtft->offset) }
        elsif ($pressed eq 'q') { $quantize = $quantize ? 0 : 1; log_it(quantize => $quantize) }
        elsif ($pressed eq 'i') { $triplets = $triplets ? 0 : 1; log_it(triplets => $triplets) }
        elsif ($pressed eq '-') { $direction = $direction ? 0 : 1; log_it(direction => $direction) }
        elsif ($pressed eq ',') { $rtfd->bpm($rtfd->bpm + ($direction ? 1 : -1)); log_it(bpm => $rtfd->bpm) }
        elsif ($pressed eq '.') { $rtfd->bpm($rtfd->bpm + ($direction ? 2 : -2)); log_it(bpm => $rtfd->bpm) }
        elsif ($pressed eq '/') { $rtfd->bpm($rtfd->bpm + ($direction ? 10 : -10)); log_it(bpm => $rtfd->bpm) }
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
    @filter_names = ();
    $rtc->filters({});
    $rtft->channel(CHANNEL);
    $rtfm->channel(CHANNEL);
    $rtft->arp([]);
    $rtft->arp_type('up');
    $rtft->delay(0.1); # seconds
    $rtfm->delay(0.1); # seconds
    $rtft->feedback(1);
    $rtfm->feedback(1);
    $rtfd->bars(1);
    $rtft->offset(OFFSET);
    $rtft->scale(SCALE);
    $rtfd->bpm(BPM);
    $direction = 1; # offset 0=below, 1=above
    $quantize  = 0;
    $triplets  = 0;
    $events    = [];
}

sub status {
    print "\n", join "\n",
        "Filter(s): @filter_names",
        'Channel: ' . $rtft->channel,
        'Pedal-tone: ' . $rtft->pedal,
        'Arp type: ' . $rtft->arp_type,
        'Delay: ' . $rtft->delay,
        'Feedback: ' . $rtft->feedback,
        'Offset distance: ' . $rtft->offset,
        'Offset direction: ' . ($direction ? 'up' : 'down'),
        'Scale name: ' . $rtft->scale,
        'BPM: ' . $rtfd->bpm,
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
        'z : stair-step filter',
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

sub channel {
    my $chan = $channels->next;
    $rtft->channel($chan);
    $rtfm->channel($chan);
    log_it(channel => $rtft->channel) 
}

sub feedback ($key) {
    $rtft->feedback($key);
    $rtfm->feedback($key);
    $rtfd->bars($key);
    log_it(feedback => $rtft->feedback) 
}

sub delay ($key) {
    if ($key eq '<') {
        unless ($rtft->delay <= 0) {
            $rtft->delay($rtft->delay - DELAY_INC);
            $rtfm->delay($rtfm->delay - DELAY_INC);
        }
    }
    else {
        $rtft->delay($rtft->delay + DELAY_INC);
        $rtfm->delay($rtft->delay + DELAY_INC);
    }
    log_it(delay => $rtft->delay);
}

sub engage ($name) {
    $filter{$name}->() unless is_member($name => \@filter_names);
    log_it(filters => join(', ', @filter_names));
}

sub add_filters ($name, $coderef, $types) {
    $types ||= [qw(note_on note_off)];
    push @filter_names, $name;
    $rtc->add_filter($name, $types, $coderef);
}

#--- FILTERS ---#

sub score ($port, $dt, $event) {
    my ($ev, $chan, $note, $vel) = $event->@*;
    if ($ev eq 'control_change' && $note == 26 && $vel == 127) { # record
        $recording = 1;
        log_it(recording => 'on');
        my $d = MIDI::Drummer::Tiny->new(
            bpm => $rtfd->bpm,
        );
        my $part = sub {
            my (%args) = @_;
            $args{drummer}->count_in($args{bars});
        };
        MIDI::RtMidi::ScorePlayer->new(
          device   => $rtc->midi_out,
          score    => $d->score,
          common   => { drummer => $d, bars => $rtfd->bars },
          parts    => [ $part ],
          sleep    => 0,
          infinite => 0,
        )->play_async->retain;
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
            my $score = setup_score(lead_in => 0, bpm => $rtfd->bpm);
            my $lengths = reverse_dump('length');
            %$lengths = map { $_ => $lengths->{$_} } grep { $lengths->{$_} !~ /^t/ } keys %$lengths
                unless $triplets;
            %$lengths = map { $_ => $lengths->{$_} } grep { $lengths->{$_} !~ /[xyz]/ } keys %$lengths; # UGH
            my $common = { score => $score, events => $events, bpm => $rtfd->bpm, lengths => $lengths };
            MIDI::RtMidi::ScorePlayer->new(
              device   => $rtc->midi_out,
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
