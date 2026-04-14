#!/usr/bin/env perl

# > morbo volca-drum-cc.pl --verbose --listen http://127.0.0.1:3333

use v5.36;
use feature 'try';
use Mojolicious::Lite -signatures;
use MIDI::RtMidi::FFI::Device ();
use Data::Dumper::Compact qw(ddc);
use Storable qw(retrieve store);

use constant PATCHES => './patches.dat';

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

END {
  if (defined $device) {
    $device->stop if defined $device;
    $device->panic if defined $device;
  }
}

sub devices () {
  my $midi_out = RtMidiOut->new;
  my @devices = keys $midi_out->get_all_port_names()->%*;
  return \@devices;
}

get '/' => sub ($c) {
  my $name = $c->param('device') || '';
  my $patch = $c->param('patch') || '';
  my $program = $c->param('program') // 0;
  my $devices = devices();
  # say ddc $devices;
  unless (-e PATCHES) {
    store({}, PATCHES);
  }
  my $patches = retrieve(PATCHES);
  $patches = [ keys %$patches ];
  $c->render(
    template => 'index',
    devices  => $devices,
    device   => $name,
    connect  => $device,
    program  => $program,
    patch    => $patch,
    patches  => $patches,
    value    => '-',
    ccs      => \%ccs,
  );
} => 'display';

post '/' => sub ($c) {
  my $chan = $c->param('channel');
  my $num = $c->param('num');
  my $val = $c->param('val');
  # say "C: $chan, N: $num, V: $val";
  $device->cc($chan, $num, $val);
} => 'submit';

post '/connect' => sub ($c) {
  my $name = $c->param('device');
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
  try {
    $device->start if defined $device;
    $c->res->code(200);
    $c->render(text => 'Success');
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(text => "Error: $e");
  }
} => 'start';

post '/stop' => sub ($c) {
  try {
    $device->stop if defined $device;
    $c->res->code(200);
    $c->render(text => 'Success');
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(text => "Error: $e");
  }
} => 'stop';

post '/program' => sub ($c) {
  my $chan = $c->param('channel');
  my $program = $c->param('program');
  try {
    $device->program_change($chan, $program);
    $c->res->code(200);
    $c->render(text => 'Success');
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(text => "Error: $e");
  }
} => 'program';

post '/recall' => sub ($c) {
  my $chan = $c->param('channel');
  my $patch = $c->param('recall');
  my $patches = retrieve(PATCHES);
  try {
    for my $channel (keys $patches->{$patch}->%*) {
      for my $cc (keys $patches->{$patch}{$channel}->%*) {
        $device->cc($channel, $cc, $patches->{$patch}{$channel}{$cc});
      }
    }
    $c->res->code(200);
    $c->render(json => $patches->{$patch}{$chan});
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(json => { error => $e });
  }
} => 'recall';

post '/save' => sub ($c) {
  my $chan = $c->param('channel');
  my $patch = $c->param('patch');
  my $ccs = $c->param('ccs');
  my $patches = retrieve(PATCHES);
  my %cc = map { split /:/, $_, 2 } split(/,\s*/, $ccs);
  %cc = map { $_ => $cc{$_} } grep { $cc{$_} !~ /^-,?$/ } keys %cc;
  $patches->{$patch}{$chan} = { %cc };
  try {
    store($patches, PATCHES);
    $c->res->code(200);
    $c->render(json => { patch => $patch });
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(json => { error => $e });
  }
} => 'save';

post '/delete' => sub ($c) {
  my $patch = $c->param('patch');
  my $patches = retrieve(PATCHES);
  try {
    if (exists $patches->{$patch}) {
      delete $patches->{$patch};
      store($patches, PATCHES);
    }
    $c->res->code(200);
    $c->render(json => { status => 'ok' });
  }
  catch ($e) {
    $c->res->code(404);
    $c->render(json => { error => $e });
  }
} => 'delete';

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
      width: 400px;
      font-family: sans-serif;
      margin: 10px;
    }
    .cc-value {
      padding-top: 5px;
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
    .parent {
      position: relative;
      height: 22px;
    }
    .green-circle {
      width: 20px;
      height: 20px;
      background-color: #4CAF50;
      border-radius: 50%;
      position: absolute;
      bottom: 0;
    }
    .red-circle {
      width: 20px;
      height: 20px;
      background-color: #ca3833;
      border-radius: 50%;
      position: absolute;
      bottom: 0;
    }
  </style>
</head>
<body>
  <h2 class="pad-left">Volca Drum CC</h2>
  <div class="block parent">
  <form action="<%= url_for('connect') %>" method="post" class="block">
    <span class="pad-left">Device:</span><select name="device">
% for my $d (@$devices) {
      <option value="<%= $d %>" <%= $d eq $device ? 'selected' : '' %>><%= $d %></option>
% }
    </select>
    <input type="submit" value="Connect">
  </form>
  &nbsp;
% if (defined $connect) { # TODO red / green connected device state
  <div class="block green-circle"></div>
% } else {
  <div class="block red-circle"></div>
% }
  </div>
  <p></p>
  <span class="pad-left">Program:</span><select name="program" id="program">
% for my $p (0 .. 15) {
    <option value="<%= $p %>" <%= $p eq $program ? 'selected' : '' %>><%= $p + 1 %></option>
% }
  </select>
  &nbsp;
  <button type="button" id="start">Start</button>
  <button type="button" id="stop">Stop</button>
  <p></p>
  <span class="pad-left">Patch:</span><input type="text" name="patch" id="patch" size="10">
  <button type="button" id="save">Save</button>
  <span class="pad-left">Recall:</span><select name="recall" id="recall">
    <option value="-">-</option>
% for my $p (sort @$patches) {
    <option value="<%= $p %>" <%= $p eq $patch ? 'selected' : '' %>><%= $p %></option>
% }
  </select>
  <button type="button" id="delete" onclick="if(!confirm('Delete patch?')) return false;">Delete</button>
  <p></p>
  <form method="post">
    <span class="pad-left">Part:</span> <select id="channel">
% for my $n (0 .. 5) {
      <option value="<%= $n %>"><%= $n + 1 %></option>
% }
    </select>
    <p></p>
% for my $cc (sort { $ccs->{$a} <=> $ccs->{$b} } keys %$ccs) {
    <div class="slider-container">
      <span class="value-display"><%= $cc %> (<%= $ccs->{$cc} %>): </span><span id="value-<%= $ccs->{$cc} %>" class="cc-value"><%= $value %></span>
      <input type="range" id="slider-<%= $ccs->{$cc} %>" min="0" max="127" value="<%= $value %>" step="1" class="range">
    </div>
% }
  </form>
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
          url: '<%= url_for("submit") %>' + '?channel=' + chan + '&num=' + num + '&val=' + val,
          type: 'POST',
        });
      }
  });
  $('#program').change(function(event) {
    var chan = $('#channel').val();
    var program = $('#program').val();
    $.ajax({
      url: '<%= url_for("program") %>' + '?channel=' + chan + '&program=' + program,
      type: 'POST',
    });
  });
  $('#start').click(function(event) {
    $.ajax({
      url: '<%= url_for("start") %>',
      type: 'POST',
    });
  });
  $('#stop').click(function(event) {
    $.ajax({
      url: '<%= url_for("stop") %>',
      type: 'POST',
    });
  });
  $('#channel').change(function(event) {
    var chan = $('#channel').val();
    var patch = $('#recall').val();
    if (patch != '-') {
      $.ajax({
        url: '<%= url_for("recall") %>' + '?channel=' + chan + '&recall=' + patch,
        type: 'POST',
        dataType: 'json',
        success: function(data) {
          $.each($('.cc-value'), function(index, value) {
              $('#value-' + index).text('-');
          });
          $.each($('.range'), function(index, value) {
              $('#slider-' + index).val(64);
          });
          $.each(data, function(index, value) {
              $('#value-' + index).text(value);
              $('#slider-' + index).val(value);
          });
        },
        error: function(err) {
          console.log(err.responseText);
        }
      });
    }
  });
  $('#recall').change(function(event) {
    var chan = $('#channel').val();
    var patch = $('#recall').val();
    console.log(patch);
    if (patch == '-') {
      $.each($('.cc-value'), function(index, value) {
        $('#value-' + index).text('-');
      });
      $.each($('.range'), function(index, value) {
        $('#slider-' + index).val(64);
      });
    }
    else {
      $.ajax({
        url: '<%= url_for("recall") %>' + '?channel=' + chan + '&recall=' + patch,
        type: 'POST',
        dataType: 'json',
        success: function(data) {
          //console.log(data);
          $.each(data, function(index, value) {
            //console.log(index + ": " + value);
            $('#value-' + index).text(value);
            $('#slider-' + index).val(value);
          });
        },
        error: function(err) {
          console.log(err.responseText);
        }
      });
    }
  });
  $('#save').click(function(event) {
    var chan = $('#channel').val();
    var patch = $('#patch').val();
    var ccs = '';
% my $i = 0;
% for my $cc (sort { $ccs->{$a} <=> $ccs->{$b} } keys %$ccs) {
    var value = $('#value-<%= $ccs->{$cc} %>').text();
    ccs = ccs + '<%= $ccs->{$cc} %>:' + value;
%   if ($i < scalar keys %$ccs) {
      ccs = ccs + ', ';
%   }
%   $i++;
% }
    $.ajax({
      url: '<%= url_for("save") %>' + '?channel=' + chan + '&patch=' + patch + '&ccs=' + ccs,
      type: 'POST',
        dataType: 'json',
        success: function(data) {
          var allValues = $('#recall option').map(function() {
            return $(this).val();
          }).get();
          $.each(data, function(index, value) {
            if (!allValues.includes(value)) {
              $('#recall').append('<option value="' + value + '" selected>' + value + '</option>');
            }
            else {
              $('#recall').val(value);
            }
            $('#patch').val('');
          });
        },
        error: function(err) {
          console.log(err.responseText);
        }
    });
  });
  $('#delete').click(function(event) {
    var patch = $('#recall').val();
    $.ajax({
      url: '<%= url_for("delete") %>' + '?patch=' + patch,
      type: 'POST',
      dataType: 'json',
      success: function(data) {
        $('#recall option:selected').remove();
      },
      error: function(err) {
        console.log(err.responseText);
      }
    });
  });
  </script>
</body>
</html>
