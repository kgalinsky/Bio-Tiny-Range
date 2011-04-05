package Bio::Tiny::Range::Base;

use strict;
use warnings;

use base qw(
  Bio::Tiny::Range::Base::Basic
  Bio::Tiny::Range::Base::String
  Bio::Tiny::Range::Base::Comparisons
  );

use Carp;
use Params::Validate qw(validate validate_pos validate_with);

=head1 NAME

Bio::Tiny::Range::Base - base class for range objects

=head1 SYNOPSIS

    package MyRange;
    use base qw( Bio::Tiny::Range::Base );
    ...

=head1 DESCRIPTION

This provides the base class for range objects. It is basically a mix-in; a
combination of an interface and methods that can take advantagve of those
abstract methods to provide useful functionality.

=cut

1;
