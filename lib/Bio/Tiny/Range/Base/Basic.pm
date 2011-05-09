package Bio::Tiny::Range::Base::Basic;

use strict;
use warnings;

use Carp;
use Params::Validate;
use Log::Log4perl qw(:easy);

=head1 NAME

Bio::Tiny::Range::Base::Basic - basic range functionality

=head1 SYNOPSIS

    # The range interface expects these accessors/mutators
    $range->lower();
    $range->upper();
    $range->strand();
    
    # The following are provided based on the above
    $range->end5();
    $range->end3();

    $range->length();
    
    $range->sequence( \$sequence );

    $range->extend( $offset );
    $range->extend( $offset, $direction );

=head1 DESCRIPTION

This contains the most basic methods for range objects.

=cut

=head1 ABSTRACT METHODS

These accessors/mutators must be defined in your class.

=head2 lower

    my $lower = $range->lower();
    $range->lower($lower);

Get/set lower bound.

=head2 upper

    my $upper = $range->upper();
    $range->upper($upper);

Get/set upper bound.

=head2 strand

    my $strand = $range->strand();
    $range->strand($strand);

Get/set strand.

=cut

=head1 PUBLIC METHODS

These are mixins that require the abstract methods to function.

=cut

=head2 length

    my $length = $range->length();

Return distance between upper and lower bound.

=cut

sub length {
    my $self = shift;

    my $lower = $self->lower;
    my $upper = $self->upper;

    return undef unless ( defined($lower) && defined($upper) );

    return $upper - $lower;
}

=head1 INTERBASE/1-BASED CONVERSION

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

=head2 sequence

    $sub_ref = $range->sequence($seq_ref);

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
        get_logger( ref $self )
          ->logwarn(
            'Unable to get sequence; lower bound or length not defined');
        return;
    }

    my $substr = substr( $$seq_ref, $lower, $length );
    return \$substr;
}

1;
