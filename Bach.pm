package Bach;

# https://archive.ics.uci.edu/ml/datasets/Bach+Choral+Harmony

use strict;
use warnings;

use Text::CSV;

sub read_bach {
    my ( $file, $byid ) = @_;

    my $csv = Text::CSV->new( { binary => 1 } )
        or die 'Cannot use CSV: ', Text::CSV->error_diag();

    open my $fh, "<:encoding(utf8)", $file
        or die "Can't read $file: $!";

    my %progression;
    my %index;

    while ( my $row = $csv->getline($fh) ) {
        # 000106b_ 2 YES  NO  NO  NO YES  NO  NO YES  NO  NO  NO  NO E 5  C_M
        ( my $id = $row->[0] ) =~ s/\s*//g;

        my $notes = '';
        for my $note ( 2 .. 13 ) {
            $notes .= $row->[$note] eq 'YES' ? 1 : 0;
        }

        if ($byid) {
            $index{$id}{$notes}++; # <- For individual stats
        }
        else {
            $index{$notes}++;      # <- For global population stat
        }

        ( my $bass  = $row->[14] ) =~ s/\s*//g;
        ( my $chord = $row->[16] ) =~ s/\s*//g;

        push @{ $progression{$id} }, join( ',', $notes, $bass, $chord );
    }

    $csv->eof or $csv->error_diag();
    close $fh;

    return ( \%index, \%progression );
}

1;
