#!/usr/bin/env perl

use MIDI::RtController ();
use MIDI::RtController::Filter::CC ();
use Object::Destroyer ();

my $input_name  = shift || 'keyboard'; # midi controller device
my $output_name = shift || 'usb'; # midi output
my $n           = shift || 8; # number of filters

my @filters = get_filters(
    port      => $input_name,
    event     => [ ('control_change') x $n ],
    trigger   => [ (25) x $n ],
    filters   => [ ('scatter') x ($n / 2), ('breathe') x ($n / 2 - 1), 'flicker' ],
    init_time => 2,
    time_incr => 0.2,
);

# open the input
my $controllers = MIDI::RtController::open_controllers([$input_name], $output_name, 1);

# add the filters
MIDI::RtController::Filter::CC::add_filters(\@filters, $controllers);

$controllers->{$input_name}->run; # and now trigger a MIDI message!

# XXX maybe needed?
END: {
    for my $i (keys %$controllers) {
        Object::Destroyer->new($controllers->{$i}, 'delete');
    }
}

sub get_filters {
    my (%args) = @_;
    my @filters;
    my $t = $args{init_time};
    for my $i (1 .. $args{filters}->@*) {
        push @filters, {
            control   => $i,
            port      => $args{port},
            event     => $args{event}->[$i],
            trigger   => $args{trigger}->[$i],
            type      => $args{filters}->[$i],
            time_step => $t,
        };
        $t += $args{time_incr};
    };
    return @filters;
}
