#!/usr/bin/env perl

# Trigger samples in a directory of mp3 or wav audio.
# This works by using `mpg123`. So install that first.

use v5.40;
# use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port);
use Path::Tiny;
use Time::HiRes qw(sleep);

my $port_name = shift // 'pad';
my $samples   = shift // '../cartoon';

my $max_samples = 64;

die "No sample directory" unless -e $samples;

my $midi_in = in_port($port_name);

# get audio as a midi note-numbered sample map
my $dir = path($samples);
my $iter = $dir->iterator;
my %sample_map;
my $i = 0;
while (my $path = $iter->()) {
    next if $path->is_dir;
    next unless $path =~ /\.(mp3|wav)\z/i;
    $sample_map{ $i++ } = $path;
    last if $i >= $max_samples;
}

# ^c halt
$SIG{INT} = sub {
    say "\nStop";
    exit;
};

while (1) {
    my $msg = $midi_in->get_message_decoded;
    unless ($msg && @$msg) {
        sleep 0.002; # don't churn the cpu
        next;
    }
    my ($type, undef, @args) = @$msg;
    if ($type eq 'note_on') {
        my ($note, $velocity) = @args;
        next unless $velocity;
        if (exists $sample_map{$note}) {
            my $sample = $sample_map{$note};
            say "Note: $note -> Trigger: $sample";
            my @cmd = ('mpg123', $sample);
            system(@cmd) == 0 or warn "WARNING: system @cmd failed: $?";
        } else {
            say "Unknown note: $note";
        }
    }
}
