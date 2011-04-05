use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Bio::Tiny::Range',
    license             => 'perl',
    dist_author         => 'Kevin Galinsky <kgalinsk@jcvi.org>',
    dist_version_from   => 'lib/Bio/Tiny/Range.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Bio-Tiny-Range-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
