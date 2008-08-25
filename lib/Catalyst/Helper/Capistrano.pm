package Catalyst::Helper::Capistrano;

use strict;
use warnings;

use Carp;

use version; our $VERSION = qv('0.0.1');

sub mk_stuff {
    my ($self, $helper, $repos, $path, @servers) = @_;

    $helper->render_file('capfile', $helper->{base} . '/Capfile');
    
    my $conf_dir = $helper->{base} . '/conf';
    $helper->mk_dir($conf_dir);
    $helper->render_file('deploy', $conf_dir . '/deploy.rb', {
        name    => $helper->{app},
        repos   => $repos,
        path    => $path,
        servers => \@servers,
    });
}

=head1 NAME

Catalyst::Helper::Capistrano - Helper to generate Capistrano Config Files.

=head1 VERSION

This document describes Catalyst::Helper::Capistrano version 0.0.1


=head1 SYNOPSIS

    script/myapp_create.pl Capistrano [repository path] [deploy path] [servers]

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=over

=item mk_stuff

mk_stuff

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Catalyst::Helper::Capistrano requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-catalyst-helper-capistrano@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Masahito Ikuta  C<< <cooldaemon@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Masahito Ikuta C<< <cooldaemon@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
__DATA__

__capfile__
load 'conf/deploy'

__deploy__
require 'capistrano/recipes/deploy/scm'
require 'capistrano/recipes/deploy/strategy'

set :application, "[% name %]"
set :repository,  "[% repos %]"

set :scm, :subversion
set :deploy_via, :checkout

set(:deploy_to) { "[% path %]/#{application}" }
set(:revision)  { source.head }

set(:source)    { Capistrano::Deploy::SCM.new(scm, self) }
set(:real_revision) {
  source.local.query_revision(revision) { |cmd|
    with_env("LC_ALL", "C") {`#{cmd}`}
  }
}

set(:strategy) { Capistrano::Deploy::Strategy.new(deploy_via, self) }

set(:release_name) {
  set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S")
}

set(:releases_path) { File.join(deploy_to, "releases") }
set(:current_path)  { File.join(deploy_to, "current") }
set(:release_path)  { File.join(releases_path, release_name) }

set(:releases)         { capture("ls -x #{releases_path}").split.sort }
set(:current_release)  { File.join(releases_path, releases.last) }
set(:previous_release) { File.join(releases_path, releases[-2]) }

set(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
set(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
set(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp}

set(:latest_release) {
  exists?(:deploy_timestamped) ? release_path : current_release
}

set(:run_method) { fetch(:use_sudo, true) ? :sudo : :run }

def with_env(name, value)
  saved, ENV[name] = ENV[name], value 
  yield
ensure
  ENV[name] = saved
end

role :servers, [% counter = 0 %][% FOREACH server IN servers %][% IF 0 < counter %], [% END %]"[% server %]"[% counter = counter + 1 %][% END %]

namespace :deploy do
  desc "deploy."
  task :default do
    update
    restart
  end
  
  task :update do
    transaction do
      update_code
      symlink
    end
  end
  
  task :update_code, :except => { :no_release => true } do
    on_rollback { run "rm -rf #{release_path}; true" }
    strategy.deploy!
    finalize_update
  end

  task :finalize_update, :except => { :no_release => true } do
    stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
    asset_paths = %w(images css js).map { |p|
      "#{latest_release}/root/static/#{p}"
    }.join(" ")
    run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
  end

  task :symlink, :except => { :no_release => true } do
    on_rollback {
      run "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true"
    }
    run "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
  end

  task :restart do
    sudo "/usr/local/etc/rc.d/apache22 stop"
    sudo "/usr/local/etc/rc.d/apache22 start"
  end

  desc "rollback."
  task :rollback do
    rollback_code
    restart
  end

  task :rollback_code, :except => { :no_release => true } do
    if releases.length < 2
      abort "could not rollback the code because there is no prior release"
    else
      run "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
    end
  end

  desc "setup."
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, releases_path]
    run "umask 02 && mkdir -p #{dirs.join(' ')}"
  end

  desc "cleanup."
  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 5).to_i
    if count >= releases.length
      logger.important "no old releases to clean up"
    else
      logger.info "keeping #{count} of #{releases.length} deployed releases"
      directories = (releases - releases.last(count)).map { |release|
        File.join(releases_path, release) }.join(" ")
        invoke_command "rm -rf #{directories}", :via => run_method
    end
  end
end

