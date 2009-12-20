#!perl

use Test::More tests => 4;

BEGIN {
	use_ok( 'JCVI::Range' );
    use_ok( 'JCVI::Range::Set' );
    use_ok( 'JCVI::Range::Base' );
    use_ok( 'JCVI::Range::Set::Base' );
}

diag( "Testing JCVI::Range $JCVI::Range::VERSION, Perl $], $^X" );
