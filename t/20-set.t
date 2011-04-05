#!perl

use Test::More 'no_plan';

use Bio::Tiny::Range::Set;
use Bio::Tiny::Range;

my @a = map { Bio::Tiny::Range->new_lls( $_ * 20, 10, 1 ) }  ( 0, 1 );
my @b = map { Bio::Tiny::Range->new_lls( $_ * 20, 10, -1 ) } ( 1, 0 );

my ( $A, $B );

ok( Bio::Tiny::Range::Set->new(),        'new' );
ok( Bio::Tiny::Range::Set->new( $a[0] ), 'new with 1 + strand exon' );
ok( $A = Bio::Tiny::Range::Set->new(@a), 'new with 2 + strand exons' );
ok( Bio::Tiny::Range::Set->new( $b[0] ), 'new with 1 - strand exon' );
ok( $B = Bio::Tiny::Range::Set->new(@b), 'new with 2 - strand exons' );

my @battery = (
    [ 'lower',  0,  0 ],
    [ 'upper',  30, 30 ],
    [ 'strand', 1,  -1 ],
    [ 'end5',   1,  30 ],
    [ 'end3',   30, 1 ]
);

foreach my $def (@battery) {
    my ( $test, $pos, $neg ) = @$def;

    is( $A->$test, $pos, "+ $test correct" );
    is( $B->$test, $neg, "- $test correct" );
}
