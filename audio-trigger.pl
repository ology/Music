#!/usr/bin/env perl

# Windows program to trigger samples in a subdirectory of mp3 audio.

use v5.40;
# use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port);
use Path::Tiny;

my $port_name = shift || 'pad';

my $midi_in = in_port($port_name);

# get audio as a midi note-numbered sample map
my $dir = path('../cartoon');
my $iter = $dir->iterator;
my %sample_map;
my $i = 0;
while (my $path = $iter->()) {
    next if $path->is_dir;
    next unless $path =~ /\.mp3$/;
    $sample_map{ $i++ } = $path;
    last if $i >= 64;
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
    my ($type, $chan, $note) = @$msg;
    if ($type eq 'note_on') {
        if (exists $sample_map{$note}) {
            my $mp3 = $sample_map{$note};
            say "Note Match: $note -> Triggering: $mp3";
            my @cmd = ('start', $mp3);
            try {
                system @cmd;
            }
            catch ($e) {
                warn "Can't system @cmd: $e\n";
            }
        } else {
            say "Unknown note: $note";
        }
    }
}