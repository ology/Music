#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;

get '/' => sub {
  my $c = shift;
  my $ccs = {
    'Part Level' => 7,
    Pan => 10,
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
    Fold => 50,
    Drive => 51,
    'Dry Gain' => 52,
    Send => 103,
    'Waveguide Model' => 116,
    Decay => 117,
    Body => 118,
    Tune => 119,
  };
  $c->render(
    template => 'index',
    value    => 64,
    ccs      => $ccs,
  );
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
  <title>Slider</title>
  <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"></script>
  <style>
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
  <form>
% for my $cc (sort { $ccs->{$a} <=> $ccs->{$b} } keys %$ccs) {
    <div class="slider-container">
      <span class="value-display"><%= $cc %>: </span><span id="value-<%= $ccs->{$cc} %>"><%= $value %></span>
      <input type="range" id="slider-<%= $ccs->{$cc} %>" min="0" max="127" value="<%= $value %>" step="1" class="range">
    </div>
% }

  <script>
  $(document).ready(function() {
    $('.range').on('input', function() {
      var val = $(this).val();
      var num = $(this).attr('id').split("-");
      $('#value-' + num[1]).text(val);
    });
  });
  </script>
</body>
</html>