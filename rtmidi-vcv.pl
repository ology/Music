#!/usr/bin/env perl

use MIDI::RtController ();
use MIDI::RtController::Filter::CC ();
use Object::Destroyer ();

my $input_names = shift || 'keyboard'; # midi controller device
my $output_name = shift || 'usb'; # midi output

my $inputs = [ split /,/, $input_names ];

my $n = 4;
my @filters;
push @filters, get_filters(
    start     => 1,
    end       => 4,
    port      => $inputs->[0],
    event     => 'control_change',
    trigger   => 25,
    filter    => 'scatter',
    init_time => 1,
    time_incr => 0.2,
);
if (defined $inputs->[1]) {
    push @filters, get_filters(
        start     => 5,
        end       => 8,
        port      => $inputs->[1],
        event     => 'control_change',
        trigger   => 26,
        filter    => 'breathe',
        init_time => 1,
        time_incr => 0.2,
    );
}
if (defined $inputs->[2]) {
    $n = 2;
    push @filters, get_filters(
        start     => 9,
        end       => 12,
        port      => $inputs->[2],
        event     => 'control_change',
        trigger   => 27,
        filter    => 'flicker',
        init_time => 1,
        time_incr => 0.2,
    );
}
use Data::Dumper::Compact qw(ddc);
warn __PACKAGE__,' L',__LINE__,' ',ddc(\@filters, {max_width=>128});

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
    for my $i ($args{start} .. $args{end}) {
        push @filters, {
            control   => $i,
            port      => $args{port},
            event     => $args{event},
            trigger   => $args{trigger},
            type      => $args{filter},
            time_step => $t,
        };
        $t += $args{time_incr};
    };
    return @filters;
}
