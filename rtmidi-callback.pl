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

# for the pedal-tone filter:
use constant PEDAL => 55;   # G below middle C
use constant DELAY => 0.09; # seconds
# for the modal chord filter:
use constant NOTE  => 'C';     # key
use constant SCALE => 'major'; # mode

my $input_name  = shift || 'tempopad'; # my midi controller device
my $output_name = shift || 'fluid';    # fluidsynth

my $loop = IO::Async::Loop->new;
my $midi_ch = IO::Async::Channel->new;

my $filters = {};
my $stash   = {};

add_filter(note_on => \&chord_tone);
add_filter(note_off => \&chord_tone);

# add_filter(note_on => \&pedal_tone);
# add_filter(note_off => \&pedal_tone);

my $midi_rtn = IO::Async::Routine->new(
    channels_out => [ $midi_ch ],
    code => sub {
        my $midi_in = MIDI::RtMidi::FFI::Device->new(type => 'in');
        $midi_in->open_port_by_name(qr/\Q$input_name/i);

        $midi_in->set_callback_decoded(
            sub { $midi_ch->send($_[2]) }
        );

        sleep;
    },
);
$loop->add($midi_rtn);

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/\Q$output_name/i);

my $tick = 0;
$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick  => sub { say "Tick " . $tick++; },
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
    for my $filter ($event_filters->@*) {
        return if $filter->($event);
    }
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
    return () if $index == -1;
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
    for my $note (@notes) {
        send_it([ $ev, $channel, $note, $vel ]);
    }
    return 1;
}

sub pedal_notes ($note) {
    return PEDAL, $note, $note + 7;
}
sub pedal_tone ($event) {
    my ($ev, $channel, $note, $vel) = $event->@*;
    my @notes = pedal_notes($note);
    my $dt = 0;
    for my $note (@notes) {
        $dt += DELAY;
        delay_send($dt, [ $ev, $channel, $note, $vel ]);
    }
    return 1;
}
