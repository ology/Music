#!/usr/bin/env perl
use strict;
use warnings;

use YAML::XS qw(LoadFile);

my $config_file = shift || 'receive-midi.yaml';

my $config = LoadFile($config_file);

my $DEBUG  = $config->{debug};
my $device = $config->{device};

my @dump_tool = qw(receivemidi dev);
my @type_tool = qw(xdotool type); # nb: X11 systems only
my @key_tool  = qw(xdotool key);

my $last = '';
my $direction = '';

open(my $midi, '-|', @dump_tool, $device)
    or die "Can't fork: $!";
warn "PID: $$\n" if $DEBUG;

while (my $line = readline($midi)) {
    # warn $line; next;
    chomp $line;
    my @parts   = split /\s+/, $line;
    my $channel = $parts[1];
    my $event   = $parts[2];
    my $data    = $parts[3]; # named note-octave
    my $value   = $parts[4]; # velocity
    warn "Ev: $event, Ch: $channel, Data: $data => $value\n" if $DEBUG;

    my @cmd;

    # find a matching trigger
    for my $entry ($config->{triggers}->@*) {
        if ($event eq $entry->{event} && $data eq $entry->{data}) {
            warn "Match: $entry->{event}\n" if $DEBUG;

            my $key  = $entry->{key};
            my $text = $entry->{text};
            if (defined $key) {
                @cmd = (@key_tool, $key);
            }
            elsif (defined $text) {
                @cmd = (@type_tool, "$text\n");
            }

            last;
        }
    }

    # execute the trigger
    if (@cmd) {
        system(@cmd) == 0
            or die "system(@cmd) failed: $?";
    }
}

close $midi
    or die "Can't execute @dump_tool: $!";

__END__
> receivemidi dev "Synido TempoPAD Z-1"
channel  1   note-on           C1  59
channel  1   note-off          C1   0
channel  1   note-on          C#1 118
channel  1   note-off         C#1   0
channel  1   note-on           D1 112
channel  1   note-off          D1   0
channel  1   note-on          D#1 102
channel  1   note-off         D#1   0
