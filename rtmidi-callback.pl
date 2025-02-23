#!/usr/bin/env perl
use v5.36;

use Data::Dumper::Compact qw(ddc);
use Future::AsyncAwait;
use IO::Async::Channel ();
use IO::Async::Loop ();
use IO::Async::Routine ();
use IO::Async::Timer::Countdown ();
use IO::Async::Timer::Periodic ();
use List::SomeUtils qw(first_index);
use MIDI::RtMidi::FFI::Device ();
use Music::Chord::Note ();
use Music::Note ();
use Music::ToRoman ();
use Music::Scales qw(get_scale_notes);
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

# for the pedal-tone filter:
use constant PEDAL => 55; # G below middle C
# for the pedal-tone and delay filters:
use constant DELAY_INC => 0.05;
# for the modal chord filter:
use constant NOTE  => 'C';     # key
use constant SCALE => 'major'; # mode

my $input_name   = shift || 'tempopad'; # midi controller device
my $output_name  = shift || 'fluid';    # fluidsynth
my $filter_names = shift || '';         # chord,delay,pedal

my @filter_names = split /\s*,\s*/, $filter_names;

my %dispatch = (
    chord => sub {
        add_filter($_ => \&chord_tone) for qw(note_on note_off);
    },
    pedal => sub {
        add_filter($_ => \&pedal_tone) for qw(note_on note_off);
    },
    delay => sub {
        add_filter($_ => \&multi_delay) for qw(note_on note_off);
    },
);

my $filters = {};
my $stash   = {};

my $feedback = 1;
my $delay    = 0.1; # seconds

$dispatch{$_}->() for @filter_names;

my $loop    = IO::Async::Loop->new;
my $midi_ch = IO::Async::Channel->new;

my $midi_rtn = IO::Async::Routine->new(
    channels_out => [ $midi_ch ],
    code => sub {
        my $midi_in = MIDI::RtMidi::FFI::Device->new(type => 'in');
        $midi_in->open_port_by_name(qr/\Q$input_name/i);
        $midi_in->set_callback_decoded(sub { $midi_ch->send($_[2]) });
        sleep;
    },
);
$loop->add($midi_rtn);

my $tka = Term::TermKey::Async->new(
    term   => \*STDIN,
    on_key => sub {
        my ($self, $key) = @_;
        my $pressed = $self->format_key($key, FORMAT_VIM);
        # say "Got key: $pressed";
        if ($pressed eq '?') { say 'Haha!' }
        elsif ($pressed =~ /^\d$/) { $feedback = $pressed }
        elsif ($pressed eq '<') { $delay -= DELAY_INC unless $delay <= 0 }
        elsif ($pressed eq '>') { $delay += DELAY_INC }
        elsif ($pressed eq 'c') { $dispatch{chord}->() }
        elsif ($pressed eq 'p') { $dispatch{pedal}->() }
        elsif ($pressed eq 'd') { $dispatch{delay}->() }
        elsif ($pressed eq 'x') { $filters = {} }
        $loop->loop_stop if $key->type_is_unicode and
                            $key->utf8 eq 'C' and
                            $key->modifiers & KEYMOD_CTRL;
    },
);
$loop->add($tka);

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/\Q$output_name/i);

my $tick = 0;
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick  => sub {
            # say 'Tick ' . $tick++;
        },
    )->start
);

$loop->await(_process_midi_events());

sub add_filter ($event_type, $action) {
    push $filters->{$event_type}->@*, $action;
}

sub stash ($key, $value) {
    $stash->{$key} = $value if defined $value;
    $stash->{$key};
}

sub send_it ($event) {
    $midi_out->send_event($event->@*);
}

sub delay_send ($delay_time, $event) {
    $loop->add(
        IO::Async::Timer::Countdown->new(
            delay     => $delay_time,
            on_expire => sub { send_it($event) }
        )->start
    )
}

sub _filter_and_forward ($event) {
    my $event_filters = $filters->{ $event->[0] } // [];
    $_->($event) for $event_filters->@*;
    send_it($event);
}

async sub _process_midi_events {
    while (my $event = await $midi_ch->recv) {
        _filter_and_forward($event);
    }
}

sub chord_notes ($note) {
    my @scale = get_scale_notes(NOTE, SCALE);
    my $mn = Music::Note->new($note, 'midinum');
    my $base = uc($mn->format('isobase'));
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
sub chord_tone ($event) {
    my ($ev, $channel, $note, $vel) = $event->@*;
    my @notes = chord_notes($note);
    for my $n (@notes) {
        send_it([ $ev, $channel, $n, $vel ]);
    }
    return 1;
}

sub pedal_notes ($note) {
    return PEDAL, $note, $note + 7;
}
sub pedal_tone ($event) {
    my ($ev, $channel, $note, $vel) = $event->@*;
    my @notes = pedal_notes($note);
    my $delay_time = 0;
    for my $n (@notes) {
        $delay_time += $delay;
        last if $delay_time <= 0;
        delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
    }
    return 1;
}

sub multi_delay ($event) {
    my ($ev, $channel, $note, $vel) = $event->@*;
    my @notes = ($note) x $feedback;
    my $delay_time = 0;
    for my $n (@notes) {
        $delay_time += $delay;
        last if $delay_time <= 0;
        delay_send($delay_time, [ $ev, $channel, $n, $vel ]);
    }
    return 1;
}
