#!/usr/bin/env perl

# > morbo volca-drum-cc.pl --verbose --listen http://127.0.0.1:3333

use v5.36;
use feature 'try';
use Mojolicious::Lite -signatures;
use MIDI::RtMidi::FFI::Device ();
use Data::Dumper::Compact qw(ddc);

my $device;

my %ccs = (
  'Part Level' => 7,
  'Pan' => 10,
  'Select 1' => 14,
  'Select 2' => 15,
  'Select 1-2' => 16,
  'Level 1' => 17,
  'Level 2' => 18,
  'Level 1-2' => 19,
  'EG Attack 1' => 20,
  'EG Attack 2' => 21,
  'EG Attack 1-2' => 22,
  'EG Release 1' => 23,
  'EG Release 2' => 24,
  'EG Release 1-2' => 25,
  'Pitch 1' => 26,
  'Pitch 2' => 27,
  'Pitch 1-2' => 28,
  'Mod Amount 1' => 29,
  'Mod Amount 2' => 30,
  'Mod Amount 1-2' => 31,
  'Mod Rate 1' => 46,
  'Mod Rate 2' => 47,
  'Mod Rate 1-2' => 48,
  'Bit Reduction' => 49,
  'Fold' => 50,
  'Drive' => 51,
  'Dry Gain' => 52,
  'Send' => 103,
  'Waveguide Model' => 116,
  'Decay' => 117,
  'Body' => 118,
  'Tune' => 119,
);

sub devices () {
  my $midi_out = RtMidiOut->new;
  my @devices = keys $midi_out->get_all_port_names()->%*;
  return \@devices;
}

get '/' => sub ($c) {
  my $name = $c->param('device') || '';
  my $chan = $c->param('channel') || '';
  my $devices = devices();
  # say ddc $devices;
  $c->render(
    template => 'index',
    devices  => $devices,
    device   => $name,
    channel  => $chan,
    value    => '-',
    ccs      => \%ccs,
  );
} => 'display';

post '/' => sub ($c) {
  my $chan = $c->param('chan');
  my $num = $c->param('num');
  my $val = $c->param('val');
  # say "C: $chan, N: $num, V: $val";
  $device->cc($chan, $num, $val);
} => 'submit';

post '/connect' => sub ($c) {
  my $name = $c->param('device');
  say "N: $name";
  if ($name) {
    $device = RtMidiOut->new;
    try { # this will die on Windows but is needed for Mac
      $device->open_virtual_port('RtMidiOut');
    }
    catch ($e) {}
    $device->open_port_by_name(qr/\Q$name/i);
  }
  $c->redirect_to($c->url_for('display')->query(device => $name));
} => 'connect';

post '/start' => sub ($c) {
  $device->start if defined $device;
  $c->redirect_to('display');
} => 'start';

post '/stop' => sub ($c) {
  $device->stop if defined $device;
  $c->redirect_to('display');
} => 'stop';

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
  <title>Volca Drum CC</title>
  <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"></script>
  <style>
    .block {
      display: inline-block;
    }
    .pad-left {
      font-family: sans-serif;
      margin: 10px;
    }
    .slider-container {
      display: flex;
      gap: 10px;
      width: 300px;
      font-family: sans-serif;
      margin: 10px;
    }

    .value-display {
      display: flex;
      width: 100%;
      gap: 10px;
      padding-top: 0.3rem;
    }

    input[type="range"] {
      width: 100%;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <form action="<%= url_for('connect') %>" method="post" class="block">
    <span class="pad-left">Device:</span> <select id="device" name="device">
% for my $d (@$devices) {
      <option value="<%= $d %>" <%= $d eq $device ? 'selected' : '' %>><%= $d %></option>
% }
    </select>
    <input type="submit" value="Connect">
  </form>
  <form action="<%= url_for('start') %>" method="post" class="block">
    <input type="submit" value="Start">
  </form>
  <form action="<%= url_for('stop') %>" method="post" class="block">
    <input type="submit" value="Stop">
  </form>
  <p></p>
  <form method="post">
  <span class="pad-left">Channel:</span> <select id="channel">
% for my $n (0 .. 5) {
    <option value="<%= $n %>" <%= $n eq $channel ? 'selected' : '' %>><%= $n %></option>
% }
  </select>
  <p></p>
% for my $cc (sort { $ccs->{$a} <=> $ccs->{$b} } keys %$ccs) {
    <div class="slider-container">
      <span class="value-display"><%= $cc %>: </span><span id="value-<%= $ccs->{$cc} %>"><%= $value %></span>
      <input type="range" id="slider-<%= $ccs->{$cc} %>" min="0" max="127" value="<%= $value %>" step="1" class="range">
    </div>
% }
  <script>
  $(document).ready(function() {
    $('.range').on('input', function() {
      var num = $(this).attr('id').split("-")[1];
      var val = $(this).val();
      $('#value-' + num).text(val);
    });
  });
  $('.range').on('mouseup', function(event) {
      if (event.which === 1) {
        var chan = $('#channel').val();
        var num = $(this).attr('id').split("-")[1];
        var val = $(this).val();
        $.ajax({
          url: '<%= url_for("submit") %>' + '?chan=' + chan + '&num=' + num + '&val=' + val,
          type: 'POST',
          success: function(response) {
            console.log('Success:', response);
          },
          error: function(xhr, status, error) {
            console.error('Error:', error);
          }
        });
      }
  });
  </script>
</body>
</html>
