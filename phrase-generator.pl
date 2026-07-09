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
use Proc::Find qw(find_proc);
use IPC::Open2 qw(open2);
use Storable qw(retrieve store);

use constant {
    DIVISIONS       => 4,  # divisions of a quarter-note into 16ths
    CLOCKS_PER_BEAT => 24, # PPQN
    SAVED           => 'saved-units.dat',
};

my %opt = (
    port    => 'fluid',
    bpm     => 60,
    base    => 'C',
    verbose => 1,
);
GetOptionsFromArray(\@ARGV, \%opt,
    'port=s',
    'bpm=i',
    'base=s',
    'verbose=s',
);

store {}, SAVED unless -e SAVED;
my $saved_units = retrieve(SAVED);

my %edit; # edit a part

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
my @parts;           # Music::VoicePhrase objects
my $midi_out;        # RtMidiOut instance
my $timer_id;        # Mojo::IOLoop->recurring id while running
my ($fluid_out, $fluid_in);

my %choices = (
    patch       => midi_dump('patch2number'),
    number      => midi_dump('number2patch'),
    scale_names => scale_names(),
    pool        => {
        'wn hn'        => [qw(wn hn)],
        'hn qn'        => [qw(hn qn)],
        'qn en'        => [qw(qn en)],
        'en sn'        => [qw(en sn)],
        'wn dhn hn qn' => [qw(wn dhn hn qn)],
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
        '3 octaves' => sub ($base, $octave, $scale) {
            get_scale_MIDI($base, $octave, $scale),
            get_scale_MIDI($base, $octave + 1, $scale),
            get_scale_MIDI($base, $octave + 2, $scale);
        },
    },
    intervals => {
        '-3..-1,1..3' => [(-3 .. -1), (1 .. 3)],
        '-4..-1,1..4' => [(-4 .. -1), (1 .. 4)],
        '-5..-1,1..5' => [(-5 .. -1), (1 .. 5)],
        '-7..-1,1..7' => [(-7 .. -1), (1 .. 7)],
    },
    keys_order => [qw(
        C
        C♯
        D♭
        D
        D♯
        E♭
        E
        F
        F♯
        G♭
        G
        G♯
        A♭
        A
        A♯
        B♭
        B
    )],
    keys => {
        'C'  => 'C',
        'C♯' => 'C#',
        'D♭' => 'Db',
        'D'  => 'D',
        'D♯' => 'D#',
        'E♭' => 'Eb',
        'E'  => 'E',
        'F'  => 'F',
        'F♯' => 'F#',
        'G♭' => 'Gb',
        'G'  => 'G',
        'G♯' => 'G#',
        'A♭' => 'Ab',
        'A'  => 'A',
        'A♯' => 'A#',
        'B♭' => 'Bb',
        'B'  => 'B',
    },
    parameters => [qw(
        channel
        patch
        gate
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
    )],
);


#################################################
#  Rt-MIDI
#################################################

sub recompute_timing {
    $clock_interval = 60 / $opt{bpm} / CLOCKS_PER_BEAT;
}

sub open_midi {
    return if $midi_out;
    $midi_out = RtMidiOut->new;
    try { $midi_out->open_virtual_port('RtMidiOut') } # needed for mac
    catch ($e) { warn 'Not a Mac' if $opt{verbose} }
    sleep(1); # band-aid the race condition
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
        $note->{off} = $note->{off} = $note->{on} + $on * $p->gate; # scale the DURATION
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
    for my $n (grep { $_->{off} <= $count } $p->queue->@*) {
        say 'OFF: ', $p->{channel}, ", $count, ", ddc $n if $opt{verbose};
        $midi_out->note_off(
            $p->{channel},
            $n->{pitch},
            0
        );
    }
}

sub needs_more ($p, $count) {
    return 0 unless $p->index >= $p->queue->@*; # all notes triggered...
    my $max_off = 0;
    $max_off = $_->{off} > $max_off ? $_->{off} : $max_off for $p->queue->@*;
    return $count >= $max_off; # ...AND all have finished ringing
}

sub start_sequencer {
    return if defined $timer_id; # already running
    die "No parts configured\n" unless @parts;

    open_midi();
    send_program_changes();

    $ticks      = 0;
    $beat_count = 0;

    for my $part (@parts) {
        $part->index(0);
        $part->queue([]);
        $part->onsets([]);
    }

    $timer_id = Mojo::IOLoop->recurring($clock_interval => sub {
        $midi_out->clock;
        $ticks++;
        if ($ticks % $sixteenth == 0) {
            off($_, $beat_count) for @parts;
            for my $part (@parts) {
                populate($part, $beat_count) if needs_more($part, $beat_count);
                on($part, $beat_count);
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
    try {
        $midi_out->stop;
        $midi_out->close_port;
    }
    catch ($e) {
        warn "Error closing MIDI port: $e\n" if $opt{verbose};
    };
    undef $midi_out;
}


#################################################
#  Routes
#################################################

get '/' => sub ($c) {
    my %used_channels;
    for my $i (0 .. $#parts) {
        # don't block the channel of the unit currently being edited
        next if defined $edit{edit_part} && $i == $edit{edit_part};
        $used_channels{ $parts[$i]->{channel} } = 1;
    }
    $c->stash(
        opt           => \%opt,
        parts         => \@parts,
        choices       => \%choices,
        running       => defined($timer_id) ? 1 : 0,
        edit          => \%edit,
        used_channels => \%used_channels,
        saved         => $saved_units,
    );
    $c->render('index');
};

post '/settings' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't change while running

    my $v = $c->req->params->to_hash;
    $opt{port} = $v->{port} if defined $v->{port};
    $opt{base} = $v->{base} if defined $v->{base};
    if ($v->{bpm}) {
        $opt{bpm} = $v->{bpm} + 0;
        recompute_timing();
    }
    $opt{verbose} = $v->{verbose} ? 1 : 0;

    $c->flash(message => 'Settings saved');
    $c->redirect_to('/');
};

post '/parts' => sub ($c) {
    return $c->redirect_to('/') if defined $timer_id; # don't add while running

    my $v = $c->req->params->to_hash;

    my %params;
    $params{channel}      = ($v->{channel} // 0) + 0;
    $params{patch}        = $v->{patch} // 0;
    $params{gate}         = $v->{gate} // 1;
    $params{motif_num}    = ($v->{motif_num} || 4) + 0;
    $params{scale}        = $v->{scale} || 'major';
    $params{octave}       = ($v->{octave} // 4) + 0;
    $params{size}         = $v->{size} || 4;
    $params{pool}         = $choices{pool}{ $v->{pool} || 'wn' };
    $params{weights}      = [ split /\s+/, ($v->{weights} || (join ' ', ('0') x $params{pool}->@*)) =~ s/^\s+|\s+$//gr ];
    $params{groups}       = [ split /\s+/, ($v->{groups}  || (join ' ', ('0') x $params{pool}->@*)) =~ s/^\s+|\s+$//gr ];
    $params{pitches_name} = $v->{pitches};
    $params{pitches}      = [ $choices{pitches}{ $v->{pitches} || '1 octave' }->(
        $opt{base}, $params{octave}, $params{scale}
    ) ];
    $params{intervals_name} = $v->{intervals};
    $params{intervals} = $choices{intervals}{ $v->{intervals} || '' };
    # say ddc \%params;

    unless ($params{pool}) {
        $c->flash(error => 'Please choose a pool');
        return $c->redirect_to('/');
    }

    if (defined $v->{edit_part}) {
        my $part = $parts[ $v->{edit_part} ];
        splice(@parts, $v->{edit_part}, 1, Music::VoicePhrase->new(%params));
        $part->clear_voice;
        %edit = ();
        $c->flash(message => 'Unit ' . $v->{edit_part} . ' updated');
    }
    else {
        push @parts, Music::VoicePhrase->new(%params); #, verbose => 1);
        $c->flash(message => 'Unit ' . scalar(@parts) . ' appended');
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
    $edit{$_} = $v->{$_} for ($choices{parameters}->@*, 'edit_part');
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

post '/cycle' => sub ($c) {
    stop_sequencer();
    system('pkill -9 fluidsynth');
    my @cmd = ('fluidsynth');
    # push @cmd, '-v' if $opt{verbose};
    push @cmd, ('-m', 'coremidi', $ENV{HOME} . '/Music/soundfont/FluidR3_GM.sf2'); #, '-g', '2.0'
    my $pid = open2($fluid_out, $fluid_in, @cmd);
    $fluid_in->autoflush(1);
    undef $midi_out;
    open_midi();
    send_program_changes();
    $c->flash(message => "Fluidsynth $pid cycled");
    $c->redirect_to('/');
};

app->start;


#################################################
#  Templates
#################################################

__DATA__

@@ index.html.ep
% layout 'default';
	<section class="wrap-standard" id="column-3">
		<div class="wrap" id="gap">
			<div class="left-frame">
				<a href="#" id="topBtn"><span class="hop">screen</span> top</a>
				<div>
					<div class="panel-3">03<span class="hop">-<%= substr rand(), 2, 6 %></span></div>
					<div class="panel-4">04<span class="hop">-<%= substr rand(), 2, 6 %></span></div>
					<div class="panel-5">05<span class="hop">-<%= substr rand(), 2, 4 %>D</span></div>
					<div class="panel-6">06<span class="hop">-<%= substr rand(), 2, 6 %></span></div>
					<div class="panel-7">07<span class="hop">-<%= substr rand(), 2, 6 %></span></div>
					<div class="panel-8">08<span class="hop">-<%= substr rand(), 2, 5 %></span></div>
					<div class="panel-9">09<span class="hop">-<%= substr rand(), 2, 6 %></span></div>
					<div class="panel-10">10<span class="hop">-<%= substr rand(), 2, 2 %></span></div>
				</div>
			</div>
			<div class="right-frame">
				<div class="bar-panel">
					<div class="bar-6"></div>
					<div class="bar-7"></div>
					<div class="bar-8"></div>
					<div class="bar-9"></div>
					<div class="bar-10"></div>
				</div>
				<main>
					<h1>MIDI Phrase Generator</h1>

% if (my $err = flash('error')) {
  <h2 class="red"><strong>Error:</strong> <%= $err %></h2>
% }
% if (my $msg = flash('message')) {
  <!-- <h2 class="green"><%= $msg %></h2> -->
% }

<table border="0" cellpadding="0" cellspacing="0" id="top">
  <tr>
    <td>

<table border="0" cellpadding="0" cellspacing="0" id="child1">
  <tr>
    <td>

<h2>Engage</h2>
Status:
% if ($running) {
<span class="red"><strong>RUNNING</strong></span>
% } else {
stopped
% }
<p></p>
<div class="form-container">
  <form method="post" action="/start" class="block">
    <button type="submit" <%= $running ? 'disabled' : '' %>>▶</button>
  </form>
  <form method="post" action="/stop" class="block">
    <button type="submit" <%= $running ? '' : 'disabled' %>>⏹</button>
  </form>
</div>
<form method="post" action="/cycle" class="block">
  <button type="submit">Cycle</button>
</form>

    </td> <!-- child1 -->
    <td> <!-- child1 -->

% if (defined $edit->{edit_part}) {
<h2>Modify Unit <%= $edit->{edit_part} + 1 %></h2>
% } else {
<h2>Affix Unit</h2>
% }
<form method="post" action="/parts">
  <label>Channel
    <select name="channel">
      % for my $n (0 .. 15) {
        <option value="<%= $n %>" <%= defined $edit->{channel} && $n eq $edit->{channel} ? 'selected' : '' %> <%= $used_channels->{$n} ? 'disabled' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Patch
    <select name="patch">
      % for my $n (sort keys $choices->{patch}->%*) {
        <option value="<%= $choices->{patch}{$n} %>" <%= defined $edit->{patch} && $choices->{patch}{$n} eq $edit->{patch} ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Gate amount
    <input type="number" name="gate" value="<%= $edit->{gate} || '1.00' %>" placeholder="" step="0.01" min="0.00" max="2.00"></label>

  <label>Motifs
    <select name="motif_num">
      % for my $n (1 .. 16) {
        % my $selected = defined $edit->{motif_num} ? $edit->{motif_num} : '4';
        <option value="<%= $n %>" <%= ($edit->{motif_num} && $n == $edit->{motif_num}) || ($n == $selected) ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Scale
    <select name="scale">
      % for my $n (sort $choices->{scale_names}->@*) {
        % my $selected = defined $edit->{scale} ? $edit->{scale} : 'major';
        <option value="<%= $n %>" <%= ($edit->{scale} && $n eq $edit->{scale}) || ($n eq $selected) ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Octave
    <select name="octave">
      % for my $n (0 .. 9) {
        % my $selected = defined $edit->{octave} ? $edit->{octave} : '3';
        <option value="<%= $n %>" <%= ($edit->{octave} && $n eq $edit->{octave}) || ($n == $selected) ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Measure size
    <select name="size">
      % for my $n (qw(1 2 2.5 3 3.5), (4 .. 16)) {
        % my $selected = defined $edit->{size} ? $edit->{size} : '4';
        <option value="<%= $n %>" <%= ($edit->{size} && $n eq $edit->{size}) || ($n == $selected) ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Pool
    <select name="pool">
      % for my $n (sort keys $choices->{pool}->%*) {
        <option value="<%= $n %>" <%= $edit->{pool} && $n eq $edit->{pool} ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Weights
    <input type="text" name="weights" value="<%= $edit->{weights} %>" placeholder="e.g. 1 1 2 space separated" size="22"></label>
  <label>Groups
    <input type="text" name="groups" value="<%= $edit->{groups} %>" placeholder="e.g. 0 0 1 space separated" size="22"></label>

  <label>Pitches
    <select name="pitches">
      % for my $n (sort keys $choices->{pitches}->%*) {
        <option value="<%= $n %>" <%= $edit->{pitches} && $n eq $edit->{pitches} ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>

  <label>Intervals
    <select name="intervals">
      % for my $n (sort keys $choices->{intervals}->%*) {
        <option value="<%= $n %>" <%= $edit->{intervals} && $n eq $edit->{intervals} ? 'selected' : '' %>><%= $n %></option>
      % }
    </select>
  </label>
  <p></p>
  % if (defined $edit->{edit_part}) {
  <input type="hidden" name="edit_part" value="<%= $edit->{edit_part} %>">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Update</button>
  % } else {
  <button type="submit" <%= $running ? 'disabled' : '' %>>Affix</button>
  % }
</form>

    </td> <!-- child1 -->
  </tr> <!-- child1 -->
</table> <!-- child1 -->

  </td> <!-- top -->
</tr> <!-- top -->
<tr> <!-- top -->
  <td> <!-- top -->

<table border="0" cellpadding="0" cellspacing="0" id="child2">
  <tr>
    <td>

<h2>Units [<%= scalar @$parts %>]</h2>
% unless (@$parts) {
  <p><em>No units configured</em></p>

<button id="loadModalBtn">Load</button>
<div id="load_modal" title="Load Unit Set" style="display:none;">
  <select name="load_parts">
% for my $n (sort keys %$saved) {
    <option value="<%= $n %>" <%= $n eq $_ ? 'selected' : '' %>><%= $n %></option>
% }
  </select>
</div>
<button id="saveModalBtn" <%= !@$parts ? 'disabled' : '' %>>Save</button>
<div id="save_modal" title="Save Unit Set" style="display:none;">
  <input type="text" name="save_parts" value="667">
</div>

% } else {

<form method="post" action="/clear">
  <button type="submit" <%= $running ? 'disabled' : '' %>>Flush Cache</button>
</form>

<button id="loadModalBtn">Load</button>
<div id="load_modal" title="Load Unit Set" style="display:none;">
  <select name="load_units">
    <option value="667">667</option>
  </select>
</div>
<button id="saveModalBtn">Save</button>
<div id="save_modal" title="Save Unit Set" style="display:none;">
  <input type="text" name="save_units" value="667">
</div>

    </td> <!-- child1 -->
    <td class="left_pad"> <!-- child1 -->

<p></p>
<table border="0" cellpadding="0" cellspacing="0" id="child3">
  <tr>
    <th class="middle_align">#</th>
    <th class="middle_align">Channel</th>
    <th class="middle_align">Patch</th>
    <th class="middle_align">Motifs</th>
    <th class="middle_align">Scale</th>
    <th class="middle_align">Octave</th>
    <th class="middle_align">Pool</th>
    <th></th>
    <th></th>
</tr>
  % for my $i (0 .. $#$parts) {
    % my $p = $parts->[$i];
    <tr>
      <td class="middle_align"><%= $i + 1 %></td>
      <td class="middle_align"><%= $p->{channel} %></td>
      <td class="middle_align"><%= $choices->{number}{ $p->{patch} } %></td>
      <td class="middle_align"><%= $p->{motif_num} %></td>
      <td class="middle_align"><%= $p->{scale} %></td>
      <td class="middle_align"><%= $p->{octave} %></td>
      <td class="middle_align"><%= join(' ', $p->{pool}->@*) %></td>
      <td class="middle_align">
      <div class="form-container">
        <form method="post" action="/edit">
          <input type="hidden" name="channel" value="<%= $p->{channel} %>">
          <input type="hidden" name="patch" value="<%= $p->{patch} %>">
          <input type="hidden" name="gate" value="<%= $p->{gate} %>">
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
        <form method="post" action="/delete">
          <button type="submit" name="delete_part" value="<%= $i %>" onclick="if(!confirm('Delete part <%= $i + 1 %>?')) return false;">Delete</button>
        </form>

      </div>
      </td>
    </tr>
  % }
</table> <!-- child3 -->
% }

    </td> <!-- child2 -->
  </tr> <!-- child2 -->
</table> <!-- child2 -->

    </td> <!-- top -->
  </tr> <!-- top -->
  <tr> <!-- top -->
    <td> <!-- top -->

<table border="0" cellpadding="0" cellspacing="0" id="child4">
  <tr>
    <td>

<h2>Settings</h2>
<form method="post" action="/settings">
  <label>MIDI port <input type="text" name="port" value="<%= $opt->{port} %>"></label>
  <label>BPM <input type="number" name="bpm" value="<%= $opt->{bpm} %>" size="4"></label>
  <label>Base note
    <select name="base">
      % for my $k ($choices->{keys_order}->@*) {
        <option value="<%= $choices->{keys}{$k} %>" <%= $edit->{base} && $k eq $edit->{base} ? 'selected' : '' %>><%= $k %></option>
      % }
    </select>
  </label>
  <label><input type="checkbox" name="verbose" value="1" <%= $opt->{verbose} ? 'checked' : '' %>> verbose</label>
  <p></p>
  <button type="submit" <%= $running ? 'disabled' : '' %>>Save Settings</button>
</form>
% if ($running) {
  <p><em>Settings locked while sequencer running</em></p>
% }

    </td> <!-- child4 -->
  </tr> <!-- child4 -->
</table> <!-- child4 -->

    </td> <!-- top -->
  </tr> <!-- top -->
</table> <!-- top -->

				</main>
				<footer>
          <div class="bar-panel">
            <div class="bar-1"></div>
            <div class="bar-2"></div>
            <div class="bar-3"></div>
            <div class="bar-4"></div>
            <div class="bar-5"></div>
          </div>
          <p></p>
          Phrase Generator created by <a href="https://www.ology.net/">Gene</a><br>
					LCARS Template by <a href="https://www.thelcars.com">www.TheLCARS.com</a>
				</footer>
			</div>
		</div>
	</section>
	<div class="headtrim"> </div>
	<div class="baseboard"> </div>
<script type="text/javascript" src="js/lcars.js"></script> <!-- XXX needed? -->
<script>
$(document).ready(function() {
  $("#load_modal").dialog({
    autoOpen: false,
    modal: true,
    buttons: {
      "Close": function() {
        $(this).dialog("close");
      }
    }
  });
  $("#loadModalBtn").on("click", function() {
    $("#load_modal").dialog("open");
  });
  $("#save_modal").dialog({
    autoOpen: false,
    modal: true,
    buttons: {
      "Close": function() {
        $(this).dialog("close");
      }
    }
  });
  $("#saveModalBtn").on("click", function() {
    $("#save_modal").dialog("open");
  });
});
</script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
  <title>MIDI Phrase Generator</title>

  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
	<meta name="format-detection" content="telephone=no">
	<meta name="format-detection" content="date=no">

  <!-- Core jQuery -->
  <script src="https://code.jquery.com/jquery-4.0.0.min.js"></script>
  <!-- jQuery UI CSS -->
  <link href="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.14.2/themes/base/jquery-ui.min.css" rel="stylesheet">
  <!-- jQuery UI JavaScript -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.14.2/jquery-ui.min.js"></script>

  <link rel="stylesheet" type="text/css" href="css/styles.css">
  <link rel="stylesheet" type="text/css" href="css/classic.css"> <!-- LCARS -->

</head>
<body>
<%= content %>
</body>
</html>
