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

my %opt = (
    port    => 'fluid',
    bpm     => 60,
    base    => 'C',
    verbose => 0,
);
GetOptionsFromArray(\@ARGV, \%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'verbose=s',
);

my %edit; # edit a part

use constant {
    DIVISIONS       => 4,  # divisions of a quarter-note into 16ths
    CLOCKS_PER_BEAT => 24, # PPQN
};

# redefine what happens on ^C, same as the original script
$SIG{INT} = sub {
    say "\nStop" if $opt{verbose};
    stop_sequencer();
    exit;
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
        map { +{
            pitch    => $p->voice->rand,
            duration => $_,
            velocity => velocity(-10, 10, 110),
        } } @$motif
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

#################################################
#  Routes
#################################################

get '/' => sub ($c) {
    $c->stash(
        opt     => \%opt,
        parts   => \@parts,
        choices => \%choices,
        running => defined($timer_id) ? 1 : 0,
        edit    => \%edit,
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
    $params{patch}     = $v->{patch} // 0;
    $params{motif_num} = ($v->{motif_num} || 4) + 0;
    $params{scale}     = $v->{scale} || 'major';
    $params{octave}    = ($v->{octave} // 4) + 0;
    $params{size}      = $v->{size} || 4;
    $params{pool}      = $choices{pool}{ $v->{pool} || 'wn' };
    $params{weights}   = [ split /\s+/, ($v->{weights} || (join ' ', ('0') x $params{pool}->@*)) =~ s/^\s+|\s+$//gr ];
    $params{groups}    = [ split /\s+/, ($v->{groups}  || (join ' ', ('0') x $params{pool}->@*)) =~ s/^\s+|\s+$//gr ];
    $params{pitches_name} = $v->{pitches};
    $params{pitches}   = [ $choices{pitches}{ $v->{pitches} || '1 octave' }->(
        $opt{base}, $params{octave}, $params{scale}
    ) ];
    $params{intervals_name} = $v->{intervals};
    $params{intervals} = $choices{intervals}{ $v->{intervals} || '' };
    # say ddc \%params;

    unless ($params{pool}) {
        $c->flash(error => 'Please choose a pool.');
        return $c->redirect_to('/');
    }

    if (defined $v->{edit_part}) {
        my $part = $parts[ $v->{edit_part} ];
        $part->channel($params{channel});
        $part->patch($params{patch});
        $part->motif_num($params{motif_num});
        $part->scale($params{scale});
        $part->octave($params{octave});
        $part->size($params{size});
        $part->pool($params{pool});
        $part->weights($params{weights});
        $part->groups($params{groups});
        $part->pitches_name($params{pitches_name});
        $part->pitches($params{pitches});
        $part->intervals_name($params{intervals_name});
        $part->intervals($params{intervals});
        %edit = ();
        $c->flash(message => 'Part ' . $v->{edit_part} . ' updated.');
    }
    else {
        push @parts, Music::VoicePhrase->new(%params);
        $c->flash(message => 'Part ' . scalar(@parts) . ' added.');
    }
    $c->redirect_to('/');
};

post '/clear' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id;
    @parts = ();
    %edit = ();
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

post '/edit' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't change while running
    my $v = $c->req->params->to_hash;
    $edit{$_} = $v->{$_} for qw(
        edit_part
        channel
        patch
        motif_num
        scale
        octave
        size
        pool
        weights
        groups
        pitches
        pitches_name
        intervals
        intervals_name
    );
    $c->flash(message => 'Now editing part ' . ($edit{edit_part} + 1));
    $c->redirect_to('/');
};

post '/delete' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't change while running
    my $v = $c->req->params->to_hash;
    splice(@parts, $v->{delete_part}, 1);
    %edit = ();
    $c->flash(message => 'Deleted part ' . ($v->{delete_part} + 1));
    $c->redirect_to('/');
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
<h1>Tonal MIDI Sequencer</h1>

% if (my $err = flash('error')) {
  <h2 style="color:#b00"><strong>Error:</strong> <%= $err %></p>
% }
% if (my $msg = flash('message')) {
  <h2 style="color:#070"><%= $msg %></p>
% }

<h2>Settings</h2>
<form method="post" action="/settings">
  <label>MIDI port <input type="text" name="port" value="<%= $opt->{port} %>"></label>
  <label>BPM <input type="number" name="bpm" value="<%= $opt->{bpm} %>"></label>
  <label>Base note <input type="text" name="base" value="<%= $opt->{base} %>" size="3"></label>
  <label><input type="checkbox" name="verbose" value="1" <%= $opt->{verbose} ? 'checked' : '' %>> verbose</label>
  <p></p>
  <button type="submit" <%= $running ? 'disabled' : '' %>>Save Settings</button>
</form>
% if ($running) {
  <p><em>Settings are locked while the sequencer is running.</em></p>
% }

<h2>Parts (<%= scalar @$parts %>)</h2>
% if (@$parts) {
<table border="1" cellpadding="2" cellspacing="0">
  <tr>
    <th>#</th>
    <th>Channel</th>
    <th>Patch</th>
    <th>Motifs</th>
    <th>Scale</th>
    <th>Octave</th>
    <th>Size</th>
    <th>Pool</th>
    <th></th>
    <th></th>
</tr>
  % for my $i (0 .. $#$parts) {
    % my $p = $parts->[$i];
    <tr>
      <td><%= $i + 1 %></td>
      <td><%= $p->{channel} %></td>
      <td><%= $p->{patch} %></td>
      <td><%= $p->{motif_num} %></td>
      <td><%= $p->{scale} %></td>
      <td><%= $p->{octave} %></td>
      <td><%= $p->{size} %></td>
      <td><%= join(' ', $p->{pool}->@*) %></td>
      <td>
        <form method="post" action="/edit">
          <input type="hidden" name="channel" value="<%= $p->{channel} %>">
          <input type="hidden" name="patch" value="<%= $p->{patch} %>">
          <input type="hidden" name="motif_num" value="<%= $p->{motif_num} %>">
          <input type="hidden" name="scale" value="<%= $p->{scale} %>">
          <input type="hidden" name="octave" value="<%= $p->{octave} %>">
          <input type="hidden" name="size" value="<%= $p->{size} %>">
          <input type="hidden" name="pool" value="<%= join ' ', $p->{pool}->@* %>">
          <input type="hidden" name="weights" value="<%= join ' ', $p->{weights}->@* %>">
          <input type="hidden" name="groups" value="<%= join ' ', $p->{groups}->@* %>">
          <input type="hidden" name="pitches" value="<%= $p->{pitches_name} %>">
          <input type="hidden" name="intervals" value="<%= $p->{intervals_name} %>">
          <button type="submit" name="edit_part" value="<%= $i %>">Edit</button>
        </form>
      </td>
      <td>
        <form method="post" action="/delete">
          <button type="submit" name="delete_part" value="<%= $i %>">Delete</button>
        </form>
      </td>
    </tr>
  % }
</table>
% } else {
  <p><em>No parts configured yet.</em></p>
% }
<form method="post" action="/clear">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Clear Parts</button>
</form>

% if (defined $edit->{edit_part}) {
<h2>Edit Part <%= $edit->{edit_part} + 1 %></h2>
% } else {
<h2>Add a Part</h2>
% }
<form method="post" action="/parts">
  <label>Channel
    <select name="channel">
      % for my $ch (0 .. 15) {
        <option value="<%= $ch %>" <%= defined $edit->{channel} && $ch eq $edit->{channel} ? 'selected' : '' %>><%= $ch %></option>
      % }
    </select>
  </label>

  <label>Patch
    <select name="patch">
      % for my $k (sort keys $choices->{patch}->%*) {
        <option value="<%= $choices->{patch}{$k} %>" <%= defined $edit->{patch} && $choices->{patch}{$k} eq $edit->{patch} ? 'selected' : '' %>><%= $k %></option>
      % }
    </select>
  </label>

  <label>Motif number
    <select name="motif_num">
      % for my $n (1 .. 16) {
        <option value="<%= $n %>" <%= $edit->{motif_num} && $n == $edit->{motif_num} ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Scale
    <select name="scale">
      % for my $s ($choices->{scale_names}->@*) {
        <option value="<%= $s %>" <%= $edit->{scale} && $s eq $edit->{scale} ? 'selected' : '' %>><%= $s %></option>
      % }
    </select>
  </label>

  <label>Octave
    <select name="octave">
      % for my $o (0 .. 9) {
        <option value="<%= $o %>" <%= $edit->{octave} && $o eq $edit->{octave} ? 'selected' : '' %>><%= $o %></option>
      % }
    </select>
  </label>

  <label>Measure size
    <select name="size">
      % for my $sz (qw(1 2 2.5 3 3.5), (4 .. 16)) {
        <option value="<%= $sz %>" <%= $edit->{size} && $sz eq $edit->{size} ? 'selected' : '' %>><%= $sz %></option>
      % }
    </select>
  </label>

  <label>Pool
    <select name="pool">
      % for my $k (sort keys $choices->{pool}->%*) {
        <option value="<%= $k %>" <%= $edit->{pool} && $k eq $edit->{pool} ? 'selected' : '' %>><%= $k %></option>
      % }
    </select>
  </label>

  <label>Weights <input type="text" name="weights" value="<%= $edit->{weights} %>" placeholder="e.g. 1 1 2 space separated"></label>
  <label>Groups <input type="text" name="groups" value="<%= $edit->{groups} %>" placeholder="e.g. 0 0 1 space separated"></label>

  <label>Pitches
    <select name="pitches">
      % for my $k (sort keys $choices->{pitches}->%*) {
        <option value="<%= $k %>" <%= $edit->{pitches} && $k eq $edit->{pitches} ? 'selected' : '' %>><%= $k %></option>
      % }
    </select>
  </label>

  <label>Intervals
    <select name="intervals">
      % for my $k (sort keys $choices->{intervals}->%*) {
        <option value="<%= $k %>" <%= $edit->{intervals} && $k eq $edit->{intervals} ? 'selected' : '' %>><%= $k %></option>
      % }
    </select>
  </label>
  <p></p>
  % if (defined $edit->{edit_part}) {
  <input type="hidden" name="edit_part" value="<%= $edit->{edit_part} %>">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Update Part</button>
  % } else {
  <button type="submit" <%= $running ? 'disabled' : '' %>>Add Part</button>
  % }
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
    table, th, td {
        border: 2px solid #E5E4E2;  /* Sets width, style, and hex color */
        border-collapse: collapse;    /* Prevents double borders */
        margin-bottom: 0.75em;
    }
    td {
        text-align: center;     /* Centers text horizontally */
        vertical-align: middle; /* Centers text vertically */
    }
    button { padding: 0.4em 1em; }
  </style>
</head>
<body>
<%= content %>
</body>
</html>