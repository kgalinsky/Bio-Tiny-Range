package Bio::Tiny::Range::Base::Comparisons;

use strict;
use warnings;

use Params::Validate;
use Log::Log4perl qw(:easy);

use overload
  'cmp'    => \&compare,
  'eq'     => \&equal,
  '=='     => \&equal,
  '>='     => \&contains,
  '<='     => \&inside,
  fallback => 1;

=head1 NAME

Bio::Tiny::Range::Base::Comparisons - comparison methods for range objects

=head1 SYNOPSIS

    $range1 <=> $range2;
    $range1->spaceship( $range2 );

    $range->contains( $point );

    $range1->outside( $range2 );
    $range1->inside( $range2 );
    $range1->overlap( $range2 );

=head1 DESCRIPTION

These are methods for comparing range objects to points or other range
objects.

=cut

# Variables used for validations
our @LU  = qw(lower upper);
our @LUS = qw(lower upper strand);

=head1 PUBLIC METHODS

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
        my ( $range, $reverse ) =
          validate_pos( @_, { can => \@LU }, 0 );

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
        my ( $range, $reverse ) =
          validate_pos( @_, { can => \@LU }, 0 );

        return ( ( $self->lower <= $range->lower )
              && ( $self->upper >= $range->upper ) ) * ( $reverse ? -1 : 1 );
    }
    else {
        my ( $coord, $reverse ) = validate_pos( @_, { regex => qr/^\d+$/ }, 0 );
        die 'Makes no sense to ask if a range is inside a coordinate'
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
    foreach (@LUS) { return 0 if ( $self->$_ != $range->$_ ) }

    # Return true if all comparisons succeeded
    return 1;
}

=head2 overlap

    my $bool = $a->overlap($b);

Returns true if the two range overlap, false otherwise.

=cut

sub overlap {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LU } );
    return ( ( $self->lower < $range->upper )
          && ( $self->upper > $range->lower ) );
}

1;
