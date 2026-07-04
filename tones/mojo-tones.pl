#!/usr/bin/env perl

use Mojolicious::Lite -signatures;

use feature qw(say try signatures);
no warnings qw(experimental::try experimental::signatures);

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptionsFromArray);
use MIDI::RtMidi::FFI::Device ();
use MIDI::Util qw(dura_size midi_dump scale_names);
use Music::Scales qw(get_scale_MIDI);
use Music::VoicePhrase ();

# ---------------------------------------------------------------------
# Options (parsed out of @ARGV before Mojolicious sees the rest of it)
# ---------------------------------------------------------------------

my %opt = (
    port    => 'MIDIThing2',
    bpm     => 70,
    base    => 'C',
    verbose => 0,
);
GetOptionsFromArray(\@ARGV, \%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'verbose=s',
);

# ---------------------------------------------------------------------
# Timing constants / sequencer state
# ---------------------------------------------------------------------

use constant {
    BEATS           => 16, # beats in a phrase
    DIVISIONS       => 4,  # divisions of a quarter-note into 16ths
    CLOCKS_PER_BEAT => 24, # PPQN
};

my $clock_interval; # time / bpm / ppqn, recomputed whenever bpm changes
my $sixteenth = CLOCKS_PER_BEAT / DIVISIONS; # clocks per 16th-note
recompute_timing();

my $ticks      = 0;  # clock ticks
my $beat_count = 0;  # how many beats?
my @parts;           # configured Music::VoicePhrase objects
my @play;            # which parts are active this measure
my $midi_out;        # RtMidiOut instance, opened on start
my $timer_id;        # Mojo::IOLoop->recurring id while running

my %choices = (
    patch       => midi_dump('patch2number'),
    scale_names => scale_names(),
    pool        => {
        'wn hn'        => [qw(wn hn)],
        'wn dhn hn qn' => [qw(wn dhn hn qn)],
        'qn en'        => [qw(qn en)],
        'hn dqn qn en' => [qw(hn dqn qn en)],
        'qn den en sn' => [qw(qn den en sn)],
    },
    pitches => {
        '1 octave'  => sub ($base, $octave, $scale) {
            get_scale_MIDI($base, $octave, $scale);
        },
        '2 octaves' => sub ($base, $octave, $scale) {
            get_scale_MIDI($base, $octave, $scale),
            get_scale_MIDI($base, $octave + 1, $scale);
        },
    },
    intervals => {
        '-3..-1,1..3' => [(-3 .. -1), (1 .. 3)],
        '-4..-1,1..4' => [(-4 .. -1), (1 .. 4)],
        '-5..-1,1..5' => [(-5 .. -1), (1 .. 5)],
        '-7..-1,1..7' => [(-7 .. -1), (1 .. 7)],
    },
);

# ---------------------------------------------------------------------
# MIDI helpers
# ---------------------------------------------------------------------

sub recompute_timing {
    $clock_interval = 60 / $opt{bpm} / CLOCKS_PER_BEAT;
}

sub open_midi {
    return if $midi_out;
    $midi_out = RtMidiOut->new;
    try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
    catch ($e) { warn 'Not a Mac' if $opt{verbose} }
    try { $midi_out->open_port_by_name(qr/\Q$opt{port}/i) }
    catch ($e) { die "Can't open MIDI port: $opt{port}\n" }
    say "Sending MIDI to $opt{port} at $opt{bpm} BPM" if $opt{verbose};
    $midi_out->start;
}

sub send_program_changes {
    for my $part (@parts) {
        $midi_out->program_change($part->{channel}, $part->{patch})
            if defined $part->{patch};
    }
}

sub panic_all {
    return unless $midi_out;
    try {
        $midi_out->stop;
        $midi_out->panic;
        for my $chan (0 .. 15) {
            for my $n (0 .. 127) {
                $midi_out->note_off($chan, $n, 0);
            }
        }
    }
    catch ($e) {
        warn "Can't halt the MIDI out device: $e\n" if $opt{verbose};
    }
}

sub velocity ($min, $max, $offset) {
    return $offset + int(rand($max - $min + 1)) + $min;
}

sub populate ($p, $count) {
    my $motif = $p->motifs->[int rand $p->motifs->@*]; # TODO something clever?
    say "$count => ", ddc $motif if $opt{verbose};
    $p->queue([
        map {
            +{
                pitch    => $p->voice->rand,
                duration => $_,
                velocity => velocity(-10, 10, 110),
            }
        } @$motif
    ]);
    # compute the onsets
    my $tally = 0;
    my @ons = ($tally);
    for my $note ($p->queue->@[0 .. $p->queue->@* - 1]) {
        my $on = dura_size($note->{duration}) * DIVISIONS;
        $tally += $on;
        push @ons, $tally;
        $note->{on}  = $count + $tally - $on;
        $note->{off} = $count + $tally;
    }
    $p->onsets([ map { $count + $_ } @ons ]);
    say 'Onsets: ', ddc $p->onsets if $opt{verbose};
    say 'Queue: ', ddc $p->queue if $opt{verbose};
    $p->index(0); # reset the queue index
}

sub on ($p, $count) {
    # if we are on a beat onset, note_on!
    if (defined $p->onsets->[$p->index] && $p->onsets->[$p->index] == $count) {
        my $n = $p->queue->[$p->index];
        say 'ON: ', $p->{channel}, ', ', $p->index, ", $count, ", ddc $n if $opt{verbose};
        if ($n) {
            $midi_out->note_on(
                $p->{channel},
                $n->{pitch},
                $n->{velocity},
            );
        }
        else {
            warn "WARNING: No note to play?\n\n";
        }
        $p->increment_index;
    }
}

sub off ($p, $count) {
    for my $n (grep { $count == $_->{off} } $p->queue->@*) {
        say 'OFF: ', $p->{channel}, ", $count, ", ddc $n if $opt{verbose};
        $midi_out->note_off(
            $p->{channel},
            $n->{pitch},
            0
        );
    }
}

# ---------------------------------------------------------------------
# Sequencer start/stop (replaces IO::Async::Timer::Periodic + loop->run)
# ---------------------------------------------------------------------

sub start_sequencer {
    return if defined $timer_id; # already running
    die "No parts configured\n" unless @parts;

    open_midi();
    send_program_changes();

    $ticks      = 0;
    $beat_count = 0;
    @play       = ();

    $timer_id = Mojo::IOLoop->recurring($clock_interval => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            if (($beat_count > 0) && (@parts > 1) && ($beat_count % (DIVISIONS ** 3) == 0)) { # every 4th measure
                say "***** ALT! *****\n" if $opt{verbose};
                @play = ($parts[-1]);
                populate($_, $beat_count) for @play;
            }
            elsif ($beat_count % (DIVISIONS * DIVISIONS) == 0) { # every measure
                @play = @parts;
                populate($_, $beat_count) for @parts;
            }
            for my $part (@play) {
                on($part, $beat_count);
                off($part, $beat_count);
            }
            $beat_count++;
        }
    });
}

sub stop_sequencer {
    return unless defined $timer_id;
    Mojo::IOLoop->remove($timer_id);
    undef $timer_id;
    panic_all();
}

# redefine what happens on ^C, same as the original script
$SIG{INT} = sub {
    say "\nStop" if $opt{verbose};
    stop_sequencer();
    exit;
};

# ---------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------

get '/' => sub ($c) {
    $c->stash(
        opt     => \%opt,
        parts   => \@parts,
        choices => \%choices,
        running => defined($timer_id) ? 1 : 0,
    );
    $c->render('index');
};

post '/settings' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't change while running

    my $v = $c->req->params->to_hash;
    $opt{port} = $v->{port} if length($v->{port} // '');
    $opt{base} = $v->{base} if length($v->{base} // '');
    if (length($v->{bpm} // '')) {
        $opt{bpm} = $v->{bpm} + 0;
        recompute_timing();
    }
    $opt{verbose} = $v->{verbose} ? 1 : 0;

    $c->flash(message => 'Settings saved.');
    $c->redirect_to('/');
};

post '/parts' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't add while running

    my $v = $c->req->params->to_hash;

    my %params;
    $params{channel}   = ($v->{channel} // 0) + 0;
    $params{patch}     = $choices{patch}{ $v->{patch} // '' };
    $params{motif_num} = ($v->{motif_num} // 4) + 0;
    $params{scale}     = $v->{scale} // 'major';
    $params{octave}    = ($v->{octave} // 4) + 0;
    $params{size}      = $v->{size} // 6;
    $params{pool}      = $choices{pool}{ $v->{pool} // '' };
    $params{weights}   = [ split /\s+/, ($v->{weights} // '') =~ s/^\s+|\s+$//gr ];
    $params{groups}    = [ split /\s+/, ($v->{groups}  // '') =~ s/^\s+|\s+$//gr ];
    $params{pitches}   = [ $choices{pitches}{ $v->{pitches} // '1 octave' }->(
        $opt{base}, $params{octave}, $params{scale}
    ) ];
    $params{intervals} = $choices{intervals}{ $v->{intervals} // '' };

    unless ($params{pool}) {
        $c->flash(error => 'Please choose a pool.');
        return $c->redirect_to('/');
    }

    push @parts, Music::VoicePhrase->new(%params);
    $c->flash(message => 'Part ' . scalar(@parts) . ' added.');
    $c->redirect_to('/');
};

post '/parts/clear' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id;
    @parts = ();
    $c->redirect_to('/');
};

post '/start' => sub ($c) {
    eval { start_sequencer() };
    $c->flash(error => $@) if $@;
    $c->redirect_to('/');
};

post '/stop' => sub ($c) {
    stop_sequencer();
    $c->redirect_to('/');
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
<h1>Tonal MIDI Sequencer</h1>

% if (my $err = flash('error')) {
  <p style="color:#b00"><strong>Error:</strong> <%= $err %></p>
% }
% if (my $msg = flash('message')) {
  <p style="color:#070"><%= $msg %></p>
% }

<h2>Settings</h2>
<form method="post" action="/settings">
  <label>MIDI port <input type="text" name="port" value="<%= $opt->{port} %>"></label>
  <label>BPM <input type="number" name="bpm" value="<%= $opt->{bpm} %>"></label>
  <label>Base note <input type="text" name="base" value="<%= $opt->{base} %>" size="3"></label>
  <label><input type="checkbox" name="verbose" value="1" <%= $opt->{verbose} ? 'checked' : '' %>> verbose</label>
  <button type="submit" <%= $running ? 'disabled' : '' %>>Save Settings</button>
</form>
% if ($running) {
  <p><em>Settings are locked while the sequencer is running.</em></p>
% }

<h2>Parts (<%= scalar @$parts %>)</h2>
% if (@$parts) {
<table border="1" cellpadding="4" cellspacing="0">
  <tr><th>#</th><th>Channel</th><th>Motif #</th><th>Scale</th><th>Octave</th><th>Size</th></tr>
  % for my $i (0 .. $#$parts) {
    % my $p = $parts->[$i];
    <tr>
      <td><%= $i + 1 %></td>
      <td><%= $p->{channel} %></td>
      <td><%= $p->{motif_num} %></td>
      <td><%= $p->{scale} %></td>
      <td><%= $p->{octave} %></td>
      <td><%= $p->{size} %></td>
    </tr>
  % }
</table>
% } else {
  <p><em>No parts configured yet.</em></p>
% }
<form method="post" action="/parts/clear">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Clear Parts</button>
</form>

<h2>Add a Part</h2>
<form method="post" action="/parts">
  <label>Channel
    <select name="channel">
      % for my $ch (0 .. 15) {
        <option value="<%= $ch %>"><%= $ch %></option>
      % }
    </select>
  </label>

  <label>Patch
    <select name="patch">
      % for my $k (sort keys %{ $choices->{patch} }) {
        <option value="<%= $k %>"><%= $k %></option>
      % }
    </select>
  </label>

  <label>Motif count
    <select name="motif_num">
      % for my $n (1 .. 16) {
        <option value="<%= $n %>" <%= $n == 4 ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Scale
    <select name="scale">
      % for my $s (@{ $choices->{scale_names} }) {
        <option value="<%= $s %>"><%= $s %></option>
      % }
    </select>
  </label>

  <label>Octave
    <select name="octave">
      % for my $o (0 .. 9) {
        <option value="<%= $o %>" <%= $o == 4 ? 'selected' : '' %>><%= $o %></option>
      % }
    </select>
  </label>

  <label>Size
    <select name="size">
      % for my $sz (qw(1 2 2.5 3 3.5), (4 .. 16)) {
        <option value="<%= $sz %>" <%= $sz == 6 ? 'selected' : '' %>><%= $sz %></option>
      % }
    </select>
  </label>

  <label>Pool
    <select name="pool">
      % for my $k (sort keys %{ $choices->{pool} }) {
        <option value="<%= $k %>"><%= $k %></option>
      % }
    </select>
  </label>

  <label>Weights <input type="text" name="weights" placeholder="e.g. 1 1 2 (space separated, one per pool item)"></label>
  <label>Groups <input type="text" name="groups" placeholder="e.g. 0 0 1 (space separated, one per pool item)"></label>

  <label>Pitches
    <select name="pitches">
      % for my $k (sort keys %{ $choices->{pitches} }) {
        <option value="<%= $k %>"><%= $k %></option>
      % }
    </select>
  </label>

  <label>Intervals
    <select name="intervals">
      % for my $k (sort keys %{ $choices->{intervals} }) {
        <option value="<%= $k %>"><%= $k %></option>
      % }
    </select>
  </label>

  <button type="submit" <%= $running ? 'disabled' : '' %>>Add Part</button>
</form>

<h2>Player</h2>
<p>Status: <strong><%= $running ? 'RUNNING' : 'stopped' %></strong></p>
<form method="post" action="/start" style="display:inline-block">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Start</button>
</form>
<form method="post" action="/stop" style="display:inline-block">
  <button type="submit" <%= $running ? '' : 'disabled' %>>Stop</button>
</form>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Tonal MIDI Sequencer</title>
  <style>
    body { font-family: sans-serif; max-width: 760px; margin: 2em auto; }
    form { margin: 0.75em 0; padding: 0.75em; border: 1px solid #ddd; border-radius: 6px; }
    label { display: inline-block; margin-right: 1em; margin-bottom: 0.5em; }
    table { margin-bottom: 0.75em; }
    button { padding: 0.4em 1em; }
  </style>
</head>
<body>
<%= content %>
</body>
</html>