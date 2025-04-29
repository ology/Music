#!/usr/bin/env perl

use MIDI::RtController ();
use MIDI::RtController::Filter::CC ();
use Object::Destroyer ();

my $input_names = shift || 'keyboard'; # midi controller device
my $output_name = shift || 'usb'; # midi output

my $inputs = [ split /,/, $input_names ];

my $n = 8; # number of filters

my @filters = get_filters(
    port      => [ ($inputs->[0]) x $n ],
    event     => [ ('control_change') x $n ],
    trigger   => [ (25) x $n ],
    filters   => [ ('scatter') x int($n / 2), ('breathe') x int($n / 2 - 1), 'flicker' ],
    init_time => 1,
    time_incr => 0.2,
);

# open the input
my $controllers = MIDI::RtController::open_controllers($inputs, $output_name, 1);

# add the filters
MIDI::RtController::Filter::CC::add_filters(\@filters, $controllers);

$controllers->{$inputs->[0]}->run; # and now trigger a MIDI message!

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
            event     => $args{event}->[$i - 1],
            trigger   => $args{trigger}->[$i - 1],
            type      => $args{filters}->[$i - 1],
            time_step => $t,
        };
        $t += $args{time_incr};
    };
    return @filters;
}
