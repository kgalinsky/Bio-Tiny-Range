package Bio::Tiny::Range::Set::Base;

use strict;
use warnings;

=head1 NAME

Bio::Tiny::Range::Set::Base - base class for sets of range

=cut

use base qw( Bio::Tiny::Range::Base );

use Carp;
use List::Util qw(min max sum);
use Params::Validate;

use Bio::Tiny::Range;

=head1 ABSTRACT METHODS

=cut

=head2 _ranges

    my $range = $set->_ranges();

This is the only method you need to define in your module. It returns an array
of ranges. It won't be modified, so it is ok to return an internal data
structure for speed.

Many methods below will have two definitions; a public one and a private one
prefixed with and underscore ('_'). The public one simply calls the private one
and passes the output of _ranges to it. The reason for this is that _ranges may
be expensive to run for some implementations of this interface, and there would
be a speed boost from computing the set of ranges once, but passing it around
to several methods for computation.

=cut

=head1 PUBLIC METHODS

=cut

=head2 ranges

    my $range = $set->ranges();

Returns an arrayref of the range in the set. This arrayref is different from
the one returned by _ranges because the order of range may be changed, but it
won't affect the actual data structure of the set.

=cut

sub ranges { [ @{ shift->_ranges() } ] }

=head1 BOUNDS MAKERS

These functions create new Bio::Tiny::Range objects

=cut

=head2 simplify

    my $range = $set->simplify();

Return a Bio::Tiny::Range object with the same endpoints and strand as the set.

=cut

sub simplify {
    my $self = shift;
    $self->_simplify( @_, $self->_ranges );
}

sub _simplify {
    my $self   = shift;
    my $range = pop;

    return undef unless (@$range);

    my $lower  = $self->_lower($range);
    my $upper  = $self->_upper($range);
    my $strand = $self->_strand($range);

    my $length = $upper - $lower;

    return Bio::Tiny::Range->new( $lower, $length, $strand );
}

=head2 introns

    my $introns = $set->introns();

Return an arrayref set of range which are the introns.

=cut

sub introns {
    my $self   = shift;
    my $range = $self->_ranges();

    return undef unless (@$range);

    @$range = sort { $a <=> $b } @$range;

    my $introns = [];

    my $a = $range->[0];
    for ( my $i = 1 ; $i < @$range ; $i++ ) {
        $b = $range->[$i];
        push @$introns, Bio::Tiny::Range->new_lus( $a->upper, $b->lower );
        $a = $b;
    }

    return $introns;
}

=head1 BOUNDS-LIKE METHODS

These are the methods that allow many of the same functions as range uses to
run.

=cut

=head2 strand

    my $strand = $set->strand();

Returns the strand.

=cut

sub strand {
    my $self = shift;
    $self->_strand( @_, $self->_ranges );
}

sub _strand {
    my $self   = shift;
    my $range = pop;

    return undef unless ( defined($range) && (@$range) );

    # Set range
    if (@_) {
        foreach my $bound (@$range) {
            $bound->strand(@_);
        }
        return @_;
    }

    # Array containing range to normalize
    my @normalize;

    # Seed strand
    my $strand = $range->[0]->strand;
    push @normalize, $range->[0] unless ($strand);

    for ( my $i = 1 ; $i < @$range ; $i++ ) {
        my $current = $range->[$i]->strand;

        # Where strand = +/-1 (not undef or 0)
        if ($strand) {
            if ($current) {

                # Return undef if two adjacent features are on opposite strands
                # This means that one feature has strand == 1, and the other
                # has strand == -1. A quick/easy test is to see if the product
                # of the two strands is -1
                return undef if ( $strand * $current == -1 );
            }

            else { push @normalize, $range->[$i] }

            next;
        }

        # Assign current to strand for cases where strand isn't +/-1
        $strand = $current if ( defined $current );
    }

    # Set the strand of range whose strands are 0/undef where others are known
    if ($strand) {
        foreach my $bound (@normalize) {
            $bound->strand($strand);
        }
    }

    return $strand;
}

=head2 lower

    my $lower = $set->lower();

Return/set lower bound

=cut

sub lower {
    my $self = shift;
    $self->_lower( @_, $self->_ranges );
}

sub _lower {
    my $self   = shift;
    my $range = pop;

    # Get the lowest bound and return it unless we were given an new one
    my $lowest = min map { $_->lower } @$range;

    return $lowest unless (@_);

    # Find the range objects whose lower bound matches the lowest bound
    foreach my $bound ( grep { $_->lower == $lowest } @$range ) {
        $bound->lower(@_);
    }
}

=head2 upper

    my $upper = $set->upper();

Return upper bound

=cut

sub upper {
    my $self = shift;
    $self->_upper( @_, $self->_ranges );
}

sub _upper {
    my $self   = shift;
    my $range = pop;

    # Get the highest bound and return it unless we were given an new one
    my $highest = max map { $_->upper } @$range;

    return $highest unless (@_);

    # Find the range objects whose upper bound matches the highest bound
    foreach my $bound ( grep { $_->upper == $highest } @$range ) {
        $bound->upper(@_);
    }
}

=head1 ADAPTED METHODS

These are methods that are similar to some of the range-like ones, but are
relevant only in a set context

=cut

=head2 spliced_sequence

Spliced sequence

=cut

sub spliced_sequence {
    my $self = shift;
    $self->_spliced_sequence( @_, $self->_ranges );
}

sub _spliced_sequence {
    my $self   = shift;
    my $range = pop;

    return undef unless (@$range);

    # Join the sequence from every bound
    my $sequence = join( '', map { ${ $_->sequence(@_) } } @$range );
    return \$sequence;
}

=head2 spliced_length

Spliced length

=cut

sub spliced_length {
    my $self = shift;
    $self->_spliced_length( @_, $self->_ranges );
}

sub _spliced_length {
    my $self   = shift;
    my $range = pop;

    return undef unless (@$range);

    return sum map { $_->length } @$range;
}

1;