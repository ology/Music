package MIDIUtil;

use strict;
use warnings;

use MIDI::Simple;
use Music::Tempo;

sub setup_midi {
    my %args = (
        lead_in => 4,
        volume  => 120,
        bpm     => 100,
        channel => 1,
        patch   => 20,
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
