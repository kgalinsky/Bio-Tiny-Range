#!perl

use Test::More tests => 27;

use Bio::Tiny::Range;

ok( Bio::Tiny::Range->new(),   'new' );
ok( Bio::Tiny::Range->new(10), 'new with lower' );
ok( Bio::Tiny::Range->new( 10, 10 ), 'new with lower/length' );
ok( Bio::Tiny::Range->new( 10, 10, 1 ), 'new with lower/length/strand' );

# Tests for failure

eval { Bio::Tiny::Range->new(-10) };
ok( $@, 'negative lower' );

eval { Bio::Tiny::Range->new('a') };
ok( $@, 'letter lower' );

eval { Bio::Tiny::Range->new('5a') };
ok( $@, 'letter + number lower' );

eval { Bio::Tiny::Range->new( 0, -10 ) };
ok( $@, 'negative length' );

eval { Bio::Tiny::Range->new( 0, 'a' ) };
ok( $@, 'letter length' );

eval { Bio::Tiny::Range->new( 0, '5a' ) };
ok( $@, 'letter + number length' );

eval { Bio::Tiny::Range->new( 0, 0, 2 ) };
ok( $@, 'invalid number strand' );

eval { Bio::Tiny::Range->new( 0, 0, 'a' ) };
ok( $@, 'letter strand' );

eval { Bio::Tiny::Range->new( 0, 0, '-1a' ) };
ok( $@, 'letter + number strand' );

# Test that range are proper
my $range = Bio::Tiny::Range->new( 50, 100, -1 );
is( $range->lower,  50,  'lower correct' );
is( $range->length, 100, 'length correct' );
is( $range->strand, -1,  'strand correct' );
is( $range->upper,  150, 'upper correct' );
is( $range->end5,   150, 'end5 correct' );
is( $range->end3,   51,  'end3 correct' );

ok( Bio::Tiny::Range->new_53( 1, 10 ), 'new_53 works' );

my $e53 = Bio::Tiny::Range->new_53( 150, 51 );
is_deeply( $e53, $range, 'new_53 == new' );

# Test range modification
$range->lower(60);
is( $range->lower,  60,  'lower correct' );
is( $range->length, 90,  'length correct' );
is( $range->upper,  150, 'upper correct' );

$range->upper(80);
is( $range->lower,  60, 'lower correct' );
is( $range->length, 20, 'length correct' );
is( $range->upper,  80, 'upper correct' );
