#!perl

use Test::More tests => 4;

BEGIN {
	use_ok( 'Bio::Tiny::Range' );
    use_ok( 'Bio::Tiny::Range::Set' );
    use_ok( 'Bio::Tiny::Range::Base' );
    use_ok( 'Bio::Tiny::Range::Set::Base' );
}

diag( "Testing Bio::Tiny::Range $Bio::Tiny::Range::VERSION, Perl $], $^X" );
