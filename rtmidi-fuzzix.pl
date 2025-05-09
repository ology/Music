#!/usr/bin/env perl
use v5.36;

use Data::Dumper::Compact qw(ddc);
use Future::AsyncAwait;
use IO::Async::Channel;
use IO::Async::Loop;
use IO::Async::Routine;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use MIDI::RtMidi::FFI::Device;

use constant PEDAL => 55; # G below middle C
use constant STRUM_DELAY => 0.05; # seconds

my $input_name  = shift || 'tempopad'; # my midi controller device
my $output_name = shift || 'fluid';    # fluid synth

my $loop = IO::Async::Loop->new;
my $midi_ch = IO::Async::Channel->new;

my $filters = {};
my $stash   = {};

add_filter(note_on => \&pedal_tone);
add_filter(note_off => \&pedal_tone);

my $midi_rtn = IO::Async::Routine->new(
    channels_out => [ $midi_ch ],
    code => sub {
        my $midi_in = MIDI::RtMidi::FFI::Device->new(type => 'in');
        $midi_in->open_port_by_name(qr/\Q$input_name/i);

        $midi_in->set_callback_decoded(
            sub { $midi_ch->send($_[2]) }
        );

        sleep;
    }
);
$loop->add( $midi_rtn );

my $midi_out = RtMidiOut->new;
$midi_out->open_virtual_port('foo');
$midi_out->open_port_by_name(qr/\Q$output_name/i);

$SIG{TERM} = sub { $midi_rtn->kill('TERM') };

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

sub pedal_notes ($note) {
    return PEDAL, $note, $note + 7;
}

sub pedal_tone ($event) {
    my ($ev, $channel, $note, $vel) = $event->@*;
    # send_it([ $ev, $channel, $_, $vel ]) for pedal_notes($note);
    my @notes = pedal_notes($note);
    my $dt = 0;
    for my $note (@notes) {
        $dt += STRUM_DELAY;
        delay_send($dt, [ $ev, $channel, $note, $vel ]);
    }
    return 1;
}
