package Bio::Tiny::Range::Set;

use strict;
use warnings;

=head1 NAME

Bio::Tiny::Range::Set - A set of ranges

=cut 

use base qw( Bio::Tiny::Range::Set::Base );

use Carp;
use Params::Validate;

=head1 SYNOPSIS

Create an array of ranges which follows the range interface.

=cut

=head1 CONSTRUCTOR

=head2 new

    my $set = Bio::Tiny::Range::Set->new();
    my $set = Bio::Tiny::Range::Set->new( @range );

Create a new set and push any range provided onto the set

=cut

sub new {
    my $class = shift;
    my $self  = [];
    bless $self, $class;
    $self->push(@_);
    return $self;
}

sub _ranges { return $_[0] }

=head1 SET MANIPULATION METHODS

These are the methods that treat the set as an array

=cut

=head2 sort
    
    $set->sort();

Sort range in the set

=cut

sub sort {
    my $self = shift;
    @$self = sort @$self;
    return [ @$self ];
}

=head2 push

    $set->push( $bound );
    $set->push( @range );

Push range onto set. Validate each bound.

=cut

sub push {
    my $self = shift;
    my @ranges =
      validate_pos( @_, ( { can => [qw( lower upper strand )] } ) x @_ );
    CORE::push @$self, @ranges;
}

1;
