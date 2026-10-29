#!/usr/bin/env perl

# Windows mp3 trigger samples in a subdirectory of audio.

use v5.40;
use Data::Dumper::Compact qw(ddc);
use MIDI::RtMidi::Util qw(in_port all_notes_off);
use Path::Tiny;

# get audio as a midi note-numbered sample map
my @files;
my $dir = path('cartoon');
my $iter = $dir->iterator;
while (my $path = $iter->()) {
    next if $path->is_dir;
    next unless lc($path->extname) eq 'mp3';
    push @files, $path;
}
my %sample_map = map { $_ => $files[$_] } 0 .. 63;

my $midi_in = in_port('pad'); # open the midi input port

# ^c halt
$SIG{INT} = sub {
    say "\nStop";
    all_notes_off($midi_out);
    exit;
}

while (1) {
    my $msg = $midi_in->get_message_decoded;
    unless ($msg && @$msg) {
        sleep 0.002; # TODO why?
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