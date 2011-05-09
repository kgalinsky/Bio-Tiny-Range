package Bio::Tiny::Range::Mixin;

use strict;
use warnings;

use Carp;

=head1 NAME

Bio::Tiny::Range::Mixin - mixins to provide range functionality

=head1 SYNOPSIS

    package MyRangeClass;

    # see Bio::Tiny::Range for more info about these methods
    sub lower  { ... }
    sub upper  { ... }
    sub strand { ... }
    sub new_lus { ... }

    our @ISA = 'Bio::Tiny::Range::Mixin'

    1;

    my $range = MyRangeClass->new( ... );

    # coordinate methods
    $range->length;
    $range->start;
    $range->end;
    $range->end5;
    $range->end3;

    # comparison methods
    @sorted   = sort @ranges;
    @filtered = grep { ( $_ lt $int_a ) && ($_ gt $int_b ) } @ranges

    if ( $range1->contains($range2) ) { ... }
    if ( $range1->inside($range2) )   { ... }

    if ( $range1 >= $range2 ) { ... } # think set theory
    if ( $range1 <= $range2 ) { ... }
    if ( $range >= $int ) { ... }
    @filtered = grep { $range->contains($_) } @points;

    if ($range1 == $range2) { ... }

    if ($range1->overlaps($range2)) { ... }

    # geometric methods
    $union        = $range1->union($range2);        # can also use "+"
    $intersection = $range1->intersection($range2); # can also use "*"

    $range->sequence(\$sequence);

=head1 DESCRIPTION

This class provides additional range functionality if your class defines the
abstract methods required by those methods.

=cut

use Params::Validate;

# Variables used for validations
our @LU  = qw/lower upper/;
our @LUS = qw/lower upper strand/;

our $NON_NEG_INT_REGEX = qr/^\d+$/;
our $POS_INT_REGEX     = qr/^[1-9]\d*$/;
our $STRAND_REGEX      = qr/^([+-]?[01]|)$/;

our $NON_NEG_INT_VAL = {
    type  => Params::Validate::SCALAR,
    regex => $NON_NEG_INT_REGEX
};
our $POS_INT_VAL = {
    type  => Params::Validate::SCALAR,
    regex => $POS_INT_REGEX
};
our $STRAND_VAL = {
    optional => 1,
    type     => Params::Validate::UNDEF | Params::Validate::SCALAR,
    regex    => $STRAND_REGEX
};

use overload
  'cmp'    => \&compare,
  'eq'     => \&equal,
  '=='     => \&equal,
  '>='     => \&contains,
  '<='     => \&inside,
  '+'      => \&union,
  fallback => 1;

use List::Util qw/ min max reduce /;

=head1 ABSTRACT METHODS

These accessors/mutators must be defined in your class.

=head2 lower

    my $lower = $range->lower();
    $range->lower($lower);

Get/set lower bound in interbase coordinates.

=head2 upper

    my $upper = $range->upper();
    $range->upper($upper);

Get/set upper bound in interbase coordinates.

=head2 strand

    my $strand = $range->strand();
    $range->strand($strand);

Get/set strand. Strand can be 1/0/-1/undef.

=head2 new_lus

    my $range = MyRangeClass->new_lus( $lower, $upper, $strand );

Constructor.

=cut

=head1 SIMPLE METHODS

Fairly basic but useful mixins.

=cut

=head2 length

    my $length = $range->length();

Return distance between upper and lower bound.

=cut

sub length {
    my $self = shift;

    my $lower = $self->lower;
    my $upper = $self->upper;

    return unless ( defined($lower) && defined($upper) );

    return $upper - $lower;
}

=head2 sequence

    my $sub_ref = $range->sequence($seq_ref);

Extract substring from a sequence reference. Returned as a reference. The same
as:

    substr( $sequence, $range->lower, $range->length );

=cut

sub sequence {
    my $self = shift;

    # Validate that the sequence is a reference and contains the range
    my ($seq_ref) = validate_pos(
        @_,
        {
            type      => Params::Validate::SCALARREF,
            callbacks => {
                'contains range' =>
                  sub { CORE::length( ${ $_[0] } ) >= $self->upper }
            }
        }
    );

    my $lower  = $self->lower;
    my $length = $self->length;

    # Verify that we can get the subsequence
    unless ( defined($lower) && defined($length) ) {
        carp 'Unable to get sequence; lower bound or length not defined';
        return;
    }

    my $substr = substr( $$seq_ref, $lower, $length );
    return \$substr;
}

=head2 consensus_strand

    my $strand = $range->consensus_strand(@ranges);
    my $strand = Bio::Tiny::Range::Mixin->consensus_strand(@ranges);

=cut

sub consensus_strand {
    shift unless ( ref $_[0] );
    reduce { defined($a) && defined($b) && $a == $b ? $a : () }
    map { $_->strand }
      validate_pos( @_, ( { can => ['strand'] } ) x @_ );
}

=head1 1-BASED CONVERSION

Storing interbase coordinates makes sense for a variety of reasons: they can
be stored eventually as unsigned integers, calculating length is easier, you
can specify 0-width ranges, strings are indexed starting at 0 in perl. However,
most biologist understand 1-based coordinates, so the following functions
perform those transformations.

=head2 start

    $start = $range->start();
    $range->start($start);

=head2 end

    $end = $range->end();
    $range->end($end);

=cut

sub start { @_ > 1 ? $_[0]->lower( $_[1] - 1 ) + 1 : $_[0]->lower + 1 }
sub end { shift->upper(@_) }

=head1 5'/3' END CONVERSION

A range object should keep track of upper/lower and strand in some form. The
following methods convert between those values and ends.

=head2 end5

    $end5 = $range->end5();
    $range->end5($end5);

Get/set 5' end

=head2 end3

    $end3 = $range->end3();
    $range->end3($end3);

Get/set 3' end

=cut

sub end5 { shift->_end53( 1,  @_ ) }
sub end3 { shift->_end53( -1, @_ ) }

# Does the actual work of figuring out 5'/3' end
sub _end53 {
    my $self = shift;

    # $test is "On what strand does this end correspond to the start?"
    my $test = shift;

    # If strand isn't defined or 0:
    # Return the end if end5 = end3 (length == 1)
    # Return nothing otherwise (since we don't know which is which)
    # Don't allow assignment
    my $strand = $self->strand;
    unless ($strand) {
        my $length = $self->length();

        return unless ( ( defined $length ) && ( $length == 1 ) );

        return $self->start;
    }

    # Get the bound based upon the test
    my $bound = $strand == $test ? 'start' : 'end';

    # Return/set the bound
    return $self->$bound(@_);
}

=head1 COMPARISONS

=cut

=head2 compare

    my @sorted = sort { $a->compare($b) } @ranges;
	my @sorted = sort { $a cmp $b } @ranges;
	my @sorted = sort @ranges;

	my @filtered = grep { $_ lt $coordinate } @ranges

Returns -1, 0 or 1 depending upon the relative position of two ranges or a
range and a coordinate. Ranges are ordered based upon lower bound and ties are
broken by the upper bound. In the case of a coordinate, compare returns -1 if
the range is fully below the coordinate, 1 if it is fully above and 0 if the
coordinate is contained within the range.

=cut

sub compare {
    my $self = shift;
    if ( ref( $_[0] ) ) {
        my ( $range, $reverse ) = validate_pos( @_, { can => \@LU }, 0 );

        return ( ( $self->lower <=> $range->lower )
              || ( $self->upper <=> $range->upper ) ) * ( $reverse ? -1 : 1 );
    }
    else {
        my ( $coord, $reverse ) = validate_pos( @_, { regex => qr/^\d+$/ }, 0 );

        return (
              $self->upper <= $coord ? -1
            : $self->lower >= $coord ? 1
            : 0
        ) * ( $reverse ? -1 : 1 );
    }
}

=head2 contains

=head2 inside

    my $bool = $range->contains($range2);
    my $bool = $range->inside($range2);

    my $bool = $range >= $range2;
    my $bool = $range <= $range2;

    my $bool = $range->contains($coordinate);
    my $bool = $range >= $coordinate;
    my $bool = $coordinate <= $range;

Tests to see if a range contains or is inside a second range. Can also be used
to test if a range contains a coordinate. You can also use the >= and <=
operators in place of set theory superset (E<supe>) and subset (E<sube>)
comparisons. 

=cut

sub contains { shift->_contains(@_) }
sub inside { shift->_contains( $_[0], ( 1 xor $_[1] ) ) }

sub _contains {
    my $self = shift;
    if ( ref( $_[0] ) ) {
        my ( $range, $reverse ) = validate_pos( @_, { can => \@LU }, 0 );

        return ( ( $self->lower <= $range->lower )
              && ( $self->upper >= $range->upper ) ) * ( $reverse ? -1 : 1 );
    }
    else {
        my ( $coord, $reverse ) = validate_pos( @_, { regex => qr/^\d+$/ }, 0 );
        croak 'Makes no sense to ask if a range is inside a coordinate'
          if ($reverse);
        return ( ( $self->upper >= $coord ) && ( $self->lower <= $coord ) );
    }
}

=head2 equal

    my $bool = $a->equal($b);
    my $bool = ( $a == $b );

Returns true if the range have same endpoints and orientation.

=cut

sub equal {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LUS }, 0 );

    # Return false if a comparison failed
    foreach (@LUS) { return if ( $self->$_ != $range->$_ ) }

    # Return true if all comparisons succeeded
    return 1;
}

=head2 overlaps

    my $bool = $a->overlaps($b);

=cut

sub overlaps {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LU } );
    return ( ( $self->lower < $range->upper )
          && ( $self->upper > $range->lower ) );
}

=head1 GEOMETRIC METHODS

The following geometric methods create a new range object using the new_lus
constructor in your class.

=cut

=head2 union

    my $union = $range1->union($range2);
    my $union = $range1 + $range2;

=cut

sub union {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LUS }, 0 );

    return unless ( $self->overlaps($range) );

    ref($self)->new_lus(
        min( map { $_->lower } ( $self, $range ) ),
        max( map { $_->upper } ( $self, $range ) ),
        $self->consensus_strand($range)
    );
}

=head2 intersection

    my $intersection = $range1->intersection($range2);
    my $intersection = $range1 * $range2;

=cut

sub intersection {
    my $self = shift;
    return unless ( ref( $_[0] ) );
    my ($range) = validate_pos( @_, { can => \@LUS }, 0 );

    my $lower = max map { $_->lower } ( $self, $range );
    my $upper = min map { $_->upper } ( $self, $range );

    return $lower < $upper
      ? ref($self)->new_lus( $lower, $upper, $self->consensus_strand($range) )
      : ();
}

1;
