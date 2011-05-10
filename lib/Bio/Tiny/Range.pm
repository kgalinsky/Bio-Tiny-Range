package Bio::Tiny::Range;

use strict;
use warnings;

use base 'Bio::Tiny::Range::Base';

use Carp;
use List::Util qw( min max );
use Params::Validate;

use version; our $VERSION = qv('0.6.0');

=head1 NAME

Bio::Tiny::Range - class for ranges on genetic sequence data

=head1 VERSION

Version 0.6.0

=head1 SYNOPSIS

    my $range = Bio::Tiny::Range->new_53( 52, 143 );

    # get coordinates
    my $lower  = $range->lower;  # 51
    my $upper  = $range->upper;  # 143
    my $strand = $range->strand; # 1
    my $length = $range->length; # 92

    # set coordinates
    $range->lower(86);
    $range->upper(134);
    $range->strand(-1);

    # alternate coordinates
    my $start = $range->start;    # 87
    my $end   = $renge->end;      # 134 - same as "upper"
    my $end5  = $range->end5;     # 134
    my $end3  = $range->end3;     # 87

    # methods
    my $seq_ref = $range->sequence(\$sequence); 

=head1 DESCRIPTION

Store boundary information. Convert from interbase to end5/end3. Compute useful
things like length and phase. Return sequence. Range are stored as an
arrayref:

    [ $lower, $length, $strand ]

Entitites are stored in this format to make things easy to validate.

    $lower  >= 0
    $length >= 0
    $strand == -1, 0, 1, undef  # See strand method for more info

Do not access array elements directly!

    # $range->[0];     # BAD!
    $range->lower();   # GOOD!

=cut

my $LOWER_INDEX  = 0;
my $LENGTH_INDEX = 1;
my $STRAND_INDEX = 2;

=head1 CONSTRUCTORS

=cut

=head2 new_lls

    my $range = Bio::Tiny::Range->new_lls( );
    my $range = Bio::Tiny::Range->new_lls( $lower );
    my $range = Bio::Tiny::Range->new_lls( $lower, $length );
    my $range = Bio::Tiny::Range->new_lls( $lower, $length, $strand );

Most direct constructor. Pass lower, length and strand. If not provided, lower
and length default to 0, strand defaults to undef.

=cut

sub new_lls {
    my $class = shift;
    my $self  = [
        validate_pos(
            @_,
            (
                {
                    default => 0,
                    regex   => $Bio::Tiny::Range::Base::NON_NEG_INT_REGEX
                }
              ) x 2,
            {
                default => undef,
                regex   => $Bio::Tiny::Range::Base::STRAND_REGEX
            }
        )
    ];
    bless $self, $class;
}

=head2 new_53

    my $range = Bio::Tiny::Range->new_53( $end5, $end3 );

Create the class given 5' and 3' end coordinates.

=cut

sub new_53 {
    my $class = shift;
    my ( $e5, $e3 ) =
      validate_pos( @_, ($Bio::Tiny::Range::Base::POS_INT_VAL) x 2 );

    return bless( [ --$e5, $e3 - $e5, 1 ],  $class ) if ( $e5 < $e3 );
    return bless( [ --$e3, $e5 - $e3, -1 ], $class ) if ( $e3 < $e5 );
    return bless( [ $e5 - 1, 1 ], $class );
}

=head2 new_lus

    my $range = Bio::Tiny::Range->new_lus( $lower, $upper );
    my $range = Bio::Tiny::Range->new_lus( $lower, $upper, $strand );

Create the class given lower and upper bounds, and optionally a strand.

=cut

sub new_lus {
    my $class = shift;
    my ( $lower, $upper, $strand ) = validate_pos(
        @_,
        ($Bio::Tiny::Range::Base::NON_NEG_INT_VAL) x 2,
        $Bio::Tiny::Range::Base::STRAND_VAL
    );

    my $length = $upper - $lower;
    croak 'Upper bound must not be less than lower bound' if ( $length < 0 );

    return bless( [ $lower, $length, $strand ], $class );
}

=head2 new_uls

    my $range = Bio::Tiny::Range->new_ul($upper, $length);
    my $range = Bio::Tiny::Range->new_ul($upper, $length, $strand);

Specify upper and length. Useful when using a regular expression to search for
sequencing gaps:

    while ($seq =~ m/(N{20,})/g) {
        push @gaps, Bio::Tiny::Range->ul(
            pos($seq),  # pos corresponds to upper bound of regular expression
            length($1)  # $1 is the stretch of Ns found
        );
    }

=cut

sub new_uls {
    my $class = shift;
    my ( $upper, $length, $strand ) = validate_pos(
        @_,
        ($Bio::Tiny::Range::Base::NON_NEG_INT_VAL) x 2,
        $Bio::Tiny::Range::Base::STRAND_VAL
    );

    my $lower = $upper - $length;
    croak 'Upper bound must be greater than length' unless ( $lower >= 0 );

    return bless( [ $lower, $length, $strand ], $class );
}

=head2 cast

    my $range = Bio::Tiny::Range->cast( $range_like_object );

If another object implements lower/upper/strand methods, then you can cast it
as a Bio::Tiny::Range object. Also, if your range-like object implements the
get_lus method (returning lower, upper and strand as an arrayref), then cast
will use that method instead. This is useful for classes where getting
coordinate data has a computationally expensive initialization that can be
shared among the different methods.

=cut

sub cast {
    my $class = shift;
    my ($range) = validate_pos( @_, { can => [qw( lower upper strand )] } );

    return $class->new_lus(
        $range->can('get_lus')
        ? @{ $range->get_lus }
        : map { $range->$_ } qw/ lower upper strand /
    );
}

=head1 ACCESSORS

=cut

=head2 lower

    $lower = $range->lower;
    $range->lower($lower); 

Get/set the lower bound.

=cut

sub lower {
    my $self = shift;
    return $self->[$LOWER_INDEX] unless (@_);

    # Validate the lower bound
    croak 'Lower bound must be a non-negative integer'
      unless ( $_[0] =~ /$Bio::Tiny::Range::Base::NON_NEG_INT_REGEX/ );

    # Adjust the length and lower bound
    $self->_set_length( $self->upper() - $_[0] );
    return $self->[$LOWER_INDEX] = $_[0];
}

=head2 upper

    $upper = $range->upper;
    $range->upper($upper); 

Get/set the upper bound.

=cut

sub upper {
    my $self = shift;

    # upper = lower + length
    return $self->lower() + $self->length() unless (@_);

    # new_upper = lower + new_set_length
    # new_set_length = new_upper - lower
    $self->_set_length( $_[0] - $self->lower );
    return $_[0];
}

=head2 length

    $length = $range->length;

Get the length.

=cut

sub length { return $_[0][$LENGTH_INDEX] }

# Set the length. The lower bound is the anchor (upper bound changes).
sub _set_length {
    my $self = shift;

    # Validate the length
    croak 'Length must be a non-negative integer'
      unless ( $_[0] =~ /$Bio::Tiny::Range::Base::NON_NEG_INT_REGEX/ );

    return $self->[$LENGTH_INDEX] = $_[0] * 1;
}

=head2 strand

    $strand = $range->strand;
    $range->strand($strand);

Get/set the strand. Strand may be undef, 0, 1, or -1. Here are the meanings of
the four values:

    1     - "+" strand
    -1    - "-" strand
    0     - strandless
    undef - unknown

=cut

sub strand {
    my $self = shift;

    return $self->[$STRAND_INDEX] unless (@_);

    # Delete strand if undef passed
    return undef( $self->[$STRAND_INDEX] ) unless ( defined $_[0] );

    # Validate strand
    croak 'Value passed to strand must be undef, 0, 1, or -1'
      unless ( $_[0] =~ /$Bio::Tiny::Range::Base::STRAND_REGEX/ );
    return $self->[$STRAND_INDEX] = $_[0] * 1;
}

=head1 AUTHOR

Kevin Galinsky, C<"kgalinsky+cpan at gmail dot com">

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bio::Tiny::Range

=head1 ACKNOWLEDGEMENTS

J. Craig Venter Institute for allowing me to initially develop this module.
Paolo Amedeo for his input when I was working on it.

=head1 COPYRIGHT & LICENSE

Copyright (C) 2011 Kevin Galinsky

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
