use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Catalyst::Helper::Capistrano',
    license             => 'perl',
    dist_author         => 'Masahito Ikuta <cooldaemon@gmail.com>',
    dist_version_from   => 'lib/Catalyst/Helper/Capistrano.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Catalyst-Helper-Capistrano-*' ],
);

$builder->create_build_script();
