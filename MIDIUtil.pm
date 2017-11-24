package MIDIUtil;

# ABSTRACT: MIDI Utilities

use strict;
use warnings;

use MIDI::Simple;
use Music::Tempo;

our $VERSION = '0.02';

=head1 SYNOPSIS

  use MIDIUtil;
  my $score = MIDIUtil::setup_midi(%args);
  # ...
  MIDIUtil::set_chan_patch( $score, $channel, $patch );

=head1 DESCRIPTION

This module is a collection of MIDI utilities.

=head1 FUNCTIONS

=head2 setup_midi()

  MIDIUtil::setup_midi(
    lead_in => 4,
    volume  => 120,
    bpm     => 100,
    channel => 1,
    patch   => 0,
    octave  => 5,
  );

Set basic MIDI parameters, play a hi-hat lead-in and return a MIDI score object.

If the lead_in parameter is 0, then no hi-hat lead-in is played.

Named parameters and defaults:

  lead_in => 4
  volume  => 120
  bpm     => 100
  channel => 1
  patch   => 0
  octave  => 5

=cut

sub setup_midi {
    my %args = (
        lead_in => 4,
        volume  => 120,
        bpm     => 100,
        channel => 1,
        patch   => 0,
        octave  => 5,
        @_,
    );

    my $score = MIDI::Simple->new_score();

    $score->set_tempo( bpm_to_ms($args{bpm}) * 1000 );

    $score->Channel(9);
    $score->n( 'qn', 42 ) for 1 .. $args{lead_in};

    $score->Volume($args{volume});
    $score->Channel($args{channel});
    $score->Octave($args{octave});
    $score->patch_change( $args{channel}, $args{patch} );

    return $score;
}

=head2 set_chan_patch()

  MIDIUtil::set_chan_patch( $score, $channel, $patch );

Set the MIDI channel and patch.

Positional parameters and defaults:

  score:   undef (required)
  channel: 0
  patch:   1

=cut

sub set_chan_patch {
    my ( $score, $channel, $patch ) = @_;
    $channel //= 0;
    $patch   //= 1;
    $score->patch_change( $channel, $patch );
    $score->noop( 'c' . $channel );
}

1;
