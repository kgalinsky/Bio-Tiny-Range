package Bio::Tiny::Range::Set::Base;

use strict;
use warnings;

=head1 NAME

Bio::Tiny::Range::Set::Base - base class for sets of range

=cut

use base qw( Bio::Tiny::Range::Base );

use Carp;
use List::Util qw(min max sum reduce);
use Params::Validate;

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

=head1 RANGE INTERFACE METHODS

Fill in Bio::Tiny::Range::Base's abstract methods given _ranges.

=cut

=head2 lower

    my $lower = $set->lower();

Return/set lower bound

=cut

sub lower {
    my $self = shift;
    $self->_lower( @_, $self->_ranges );
}

sub _lower {
    my $self  = shift;
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
    my $self  = shift;
    my $range = pop;

    # Get the highest bound and return it unless we were given an new one
    my $highest = max map { $_->upper } @$range;

    return $highest unless (@_);

    # Find the range objects whose upper bound matches the highest bound
    foreach my $bound ( grep { $_->upper == $highest } @$range ) {
        $bound->upper(@_);
    }
}

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
    my $ranges = pop(@_);

    return undef unless ( defined($ranges) && (@$ranges) );

    # Set ranges
    if (@_) {
        foreach my $range (@$ranges) {
            $range->strand(@_);
        }
        return @_;
    }

    # Array containing range to normalize
    my @normalize;

    # Seed strand
    my $strand = $ranges->[0]->strand;
    push @normalize, $ranges->[0] unless ($strand);

    $strand = reduce {
        my $b_str = $b->strand;

        if ( !$b_str ) {

            # Normalize strand for ranges where strand isn't +/-1
            push @normalize, $b;
            $a;
        }
        else {
            unless ($a) { $b_str }
            else {

                # Return undef if two adjacent features are on opposite strands
                # This means that one feature has strand == 1, and the other
                # has strand == -1. A quick/easy test is to see if the product
                # of the two strands is -1
                return if ( $a * $b_str == -1 );
                $a;
            }
        }
    }
    ( $strand, @$ranges[ 1 .. $#$ranges ] );

    # Set strands for unstranded ranges if some were stranded
    if ($strand) {
        foreach my $range (@normalize) {
            $range->strand($strand);
        }
    }

    return $strand;
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
    my $self  = shift;
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
    my $self  = shift;
    my $range = pop;

    return undef unless (@$range);

    return sum map { $_->length } @$range;
}

=head2 as_string

=cut

{
    no warnings;
    *as_string = *_as_string = sub {
        '[' . join( ',', map { $_->_as_string } @{ $_[0]->_ranges } ) . ']';
    };
}

1;
