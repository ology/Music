#!/usr/bin/env perl

# Web interface for interval-hop-beats.pl
# perl interval-hop-web.pl daemon -l http://127.0.0.1:3000
# Set HOP_SCRIPT to point at the program if it isn't next to this file.

use v5.40;
use Mojolicious::Lite -signatures;
use Mojo::File qw(curfile);
use Mojo::IOLoop::ReadWriteFork ();

my $script = $ENV{HOP_SCRIPT} // curfile->sibling('interval-hop-beats.pl')->to_string;

# One entry per CLI option: how to render it and how to validate it.
my @fields = (
    { name => 'port',     label => 'Tonal MIDI port',  type => 'text', default => 'fluidsynth',
      re => qr/\A[\w .\-]+\z/, help => 'synth name fragment' },
    { name => 'drums',    label => 'Drum MIDI port',   type => 'text', default => 'fluidsynth',
      re => qr/\A[\w .\-]+\z/, help => 'synth name fragment' },
    { name => 'alt_chan', label => 'Drum channel',     type => 'int',  default => 9,
      min => -1, max => 15, help => '-1 means multi-timbral' },
    { name => 'channels', label => 'Channels',         type => 'text', default => '1,2',
      re => qr/\A\d+(?:\s*,\s*\d+)*\z/, help => 'comma-separated, 1-based' },
    { name => 'list',     label => 'Patches',          type => 'text', default => '37,1',
      re => qr/\A(?:-1|\d+(?:\s*,\s*\d+)*)\z/, help => 'comma-separated, or -1 for none' },
    { name => 'bpm',      label => 'BPM',              type => 'int',  default => 70,
      min => 20, max => 300 },
    { name => 'octave',   label => 'Initial octave',   type => 'int',  default => 2,
      min => 0, max => 9 },
    { name => 'num_oct',  label => 'Num. of octaves',  type => 'int',  default => 2,
      min => 1, max => 6 },
    { name => 'scale',    label => 'Scale name',       type => 'text', default => 'major',
      re => qr/\A\w+\z/, help => 'a Music::Scales name' },
    { name => 'tonic',    label => 'Tonic',            type => 'text', default => 'C',
      re => qr/\A[A-G][#b]?\z/ },
    { name => 'groups',   label => 'Durations',        type => 'text', default => '-1',
      re => qr/\A(?:-1|(?:\d+=\w+(?:,\w+)*(?:;\d+=\w+(?:,\w+)*)*)?)\z/,
      help => 'channel=durations, separated by ;  e.g. 1=wn,hn;2=qn,en (channels are 1-based; -1 for none)' },
    { name => 'jumps',    label => 'Intervals',        type => 'text', default => '-3,-2,2,3',
      re => qr/\A-?\d+(?:\s*,\s*-?\d+)*\z/, help => 'allowed voice intervals' },
    { name => 'hunk',     label => 'Together',         type => 'int',  default => 2,
      min => 1, max => 16, help => 'channels sounding at once' },
    { name => 'effect',   label => 'Change',           type => 'int',  default => 4,
      min => 1, max => 64, help => 'bars before a change' },
    { name => 'remove',   label => 'Remove 7ths',      type => 'flag' },
    { name => 'fill',     label => 'Rest on fill bar', type => 'flag' },
);

my $fork;       # the running Mojo::IOLoop::ReadWriteFork, if any
my @log;        # recent output lines, replayed to new viewers
my %clients;    # connected WebSocket transactions

sub broadcast ($msg) {
    $_->send({ json => $msg }) for values %clients;
}

sub emit ($line) {
    push @log, $line;
    shift @log while @log > 500;
    broadcast({ type => 'log', line => $line });
}

# Validate the form and turn it into a safe argument list (no shell involved).
sub build_args ($c) {
    my (@args, %errors);
    for my $f (@fields) {
        my $name = $f->{name};
        if ($f->{type} eq 'flag') {
            push @args, "--$name" if $c->param($name);
            next;
        }
        my $v = $c->param($name) // $f->{default};
        $v =~ s/\A\s+|\s+\z//g;
        my $ok = $f->{type} eq 'int'
            ? ($v =~ /\A-?\d+\z/ && $v >= $f->{min} && $v <= $f->{max})
            : ($v =~ $f->{re});
        if ($ok) { push @args, "--$name=$v" }   # --name=value keeps "-1" safe
        else     { $errors{$name} = "Invalid value for $f->{label}" }
    }
    push @args, '--verbose';
    return (\@args, \%errors);
}

get '/' => sub ($c) {
    $c->render(template => 'index', fields => \@fields);
};

get '/status' => sub ($c) {
    $c->render(json => { running => $fork ? \1 : \0 });
};

post '/start' => sub ($c) {
    return $c->render(json => { ok => \0, error => 'Already running' }, status => 409)
        if $fork;

    my ($args, $errors) = build_args($c);
    return $c->render(json => { ok => \0, errors => $errors }, status => 422)
        if %$errors;

    @log = ();
    broadcast({ type => 'backlog', lines => [] });
    emit('$ ' . join ' ', 'perl', $script, @$args);

    my $buffer = '';
    my $f = Mojo::IOLoop::ReadWriteFork->new;
    $f->on(read => sub ($f, $bytes) {
        $buffer .= $bytes;
        while ($buffer =~ s/\A([^\n]*)\n//) { emit($1) }
    });
    $f->on(error => sub ($f, $err) { emit("ERROR: $err") });
    $f->on(close => sub ($f, $exit_value, $signal) {
        emit($buffer) if length $buffer;
        emit("-- exited ($exit_value, signal $signal)");
        undef $fork;
        broadcast({ type => 'status', running => \0 });
    });
    $f->start(program => $^X, program_args => [ $script, @$args ]);

    $fork = $f;
    broadcast({ type => 'status', running => \1 });
    $c->render(json => { ok => \1 });
};

post '/stop' => sub ($c) {
    return $c->render(json => { ok => \0, error => 'Not running' }, status => 409)
        unless $fork;

    my $f = $fork;
    $f->kill('INT');    # the program traps INT and silences the MIDI ports
    Mojo::IOLoop->timer(5 => sub { $f->kill('KILL') if $fork && $fork == $f });
    $c->render(json => { ok => \1 });
};

websocket '/log' => sub ($c) {
    $c->inactivity_timeout(3600);
    my $tx = $c->tx;
    $clients{"$tx"} = $tx;
    $c->on(finish => sub { delete $clients{"$tx"} });
    $c->send({ json => { type => 'backlog', lines => [@log] } });
    $c->send({ json => { type => 'status',  running => $fork ? \1 : \0 } });
};

app->start;

__DATA__

@@ index.html.ep
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Interval Hop Beats</title>
<style>
  :root { color-scheme: light dark; --gap: .75rem; }
  body { font: 15px/1.4 system-ui, sans-serif; max-width: 70rem; margin: 1rem auto; padding: 0 1rem; }
  h1 { margin-bottom: .25rem; }
  main { display: grid; grid-template-columns: minmax(18rem, 24rem) 1fr; gap: 1.5rem; }
  @media (max-width: 800px) { main { grid-template-columns: 1fr; } }
  form label { display: grid; grid-template-columns: 8rem 1fr; gap: .25rem var(--gap); align-items: center; margin-bottom: .5rem; }
  form label small { grid-column: 2; opacity: .65; }
  input[type=text] { width: 100%; box-sizing: border-box; padding: .3rem; }
  input.bad { outline: 2px solid #d33; }
  .buttons { display: flex; gap: var(--gap); align-items: center; margin-top: 1rem; }
  button { padding: .5rem 1.25rem; font-size: 1rem; cursor: pointer; }
  #state { font-weight: 600; }
  #state.on { color: #2a9d3f; }
  #log { background: #111; color: #cfd; padding: .75rem; height: 32rem; overflow: auto;
         font: 13px/1.35 ui-monospace, monospace; white-space: pre-wrap; border-radius: 6px; margin: 0; }
  #msg { color: #d33; min-height: 1.2em; }
</style>
</head>
<body>
<h1>Interval Hop Beats</h1>
<main>
  <section>
    <form id="f" autocomplete="off">
% for my $f (@$fields) {
      <label>
        <span><%= $f->{label} %></span>
% if ($f->{type} eq 'flag') {
        <input type="checkbox" name="<%= $f->{name} %>" value="1">
% } else {
        <input type="text" name="<%= $f->{name} %>" value="<%= $f->{default} %>">
% }
% if ($f->{help}) {
        <small><%= $f->{help} %></small>
% }
      </label>
% }
      <div class="buttons">
        <button type="button" id="start">Start</button>
        <button type="button" id="stop" disabled>Stop</button>
        <span id="state">stopped</span>
      </div>
      <p id="msg"></p>
    </form>
  </section>
  <section>
    <pre id="log"></pre>
  </section>
</main>

<script>
const form  = document.getElementById('f');
const logEl = document.getElementById('log');
const stateEl = document.getElementById('state');
const msgEl = document.getElementById('msg');
const startBtn = document.getElementById('start');
const stopBtn  = document.getElementById('stop');

function setRunning(running) {
  stateEl.textContent = running ? 'running' : 'stopped';
  stateEl.classList.toggle('on', running);
  startBtn.disabled = running;
  stopBtn.disabled  = !running;
  for (const el of form.elements) if (el.name) el.disabled = running;
}

function addLine(line) {
  const atBottom = logEl.scrollTop + logEl.clientHeight >= logEl.scrollHeight - 20;
  logEl.appendChild(document.createTextNode(line + '\n'));  // text node, never HTML
  if (atBottom) logEl.scrollTop = logEl.scrollHeight;
}

function connect() {
  const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/log');
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.type === 'backlog') { logEl.textContent = ''; m.lines.forEach(addLine); }
    else if (m.type === 'log') addLine(m.line);
    else if (m.type === 'status') setRunning(m.running);
  };
  ws.onclose = () => setTimeout(connect, 1000);
}

async function post(url) {
  const r = await fetch(url, { method: 'POST', body: new URLSearchParams(new FormData(form)) });
  return [r, await r.json()];
}

startBtn.onclick = async () => {
  msgEl.textContent = '';
  form.querySelectorAll('.bad').forEach(el => el.classList.remove('bad'));
  const [r, data] = await post('/start');
  if (r.ok) return;
  if (data.errors) {
    msgEl.textContent = Object.values(data.errors).join('; ');
    for (const name of Object.keys(data.errors)) form.elements[name]?.classList.add('bad');
  } else msgEl.textContent = data.error;
};

stopBtn.onclick = async () => {
  const [, data] = await post('/stop');
  if (data.error) msgEl.textContent = data.error;
};

connect();
</script>
</body>
</html>