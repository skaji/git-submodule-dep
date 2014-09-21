package App::GitSubmoduleDep;
use 5.014;
use strict;
use warnings;
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case);
use Pod::Usage 'pod2usage';
use File::pushd;
use File::Spec::Functions qw(catfile catdir splitdir);
use File::Basename qw(basename dirname);
use File::Path qw(mkpath rmtree);
use File::Find 'find';

our $VERSION = "0.01";

package App::GitSubmoduleDep::Git {
    use Capture::Tiny 'capture';
    use version;
    sub new { bless {}, shift }
    sub run {
        my ($self, @cmd) = @_;
        my ($out, $err, $exit) = capture {
            system "git", @cmd;
        };
        if ($exit != 0) {
            chomp $err;
            die "Failed git @cmd", $err ? ": $err" : "", "\n";
        }
        if (wantarray) {
            split /\n/, $out;
        } else {
            chomp $out;
            $out;
        }
    }
    sub root_dir {
        my $self = shift;
        my $dir = $self->run(qw(rev-parse --show-toplevel));
        $dir;
    }
    sub submodule_add {
        my ($self, $url) = @_;
        $self->run(qw(submodule add), $url);
    }
    sub submodule_delete {
        my ($self, $submodule_path) = @_;
        $self->run(qw(submodule deinit -f), $submodule_path);
        $self->run(qw(rm -f), $submodule_path);
    }
    sub version {
        my $self = shift;
        my $out = $self->run("version");
        my ($v) = $out =~ m{([\d.]+)};
        version->parse($v)->numify;
    }
}


sub new {
    bless { git => App::GitSubmoduleDep::Git->new }, shift;
}
sub git { shift->{git} }

sub parse_options {
    my $self = shift;
    local @ARGV = @_;
    GetOptions
        "dir=s" => \($self->{dir} = "modules"),
        "help|h" => sub { pod2usage(0) },
        "delete|d" => \($self->{delete}),
    or pod2usage(1);
    $self->{dir} =~ s{/$}{};
    my $arg = shift @ARGV
        or do { warn "Missing argument.\n"; pod2usage(1) };
    $self->{arg} = $arg;
    $self;
}

sub run {
    my $self = shift;
    my $root_dir = $self->git->root_dir
        or die "Cannnot determine git root dir\n";
    -d "$root_dir/lib"
        or die "Missing $root_dir/lib directory\n";

    chdir $root_dir; # XXX

    if ($self->{delete}) {
        $self->delete($root_dir);
    } else {
        $self->create($root_dir);
    }
}

sub create {
    my ($self, $root_dir) = @_;

    my $dir = $self->{dir};
    mkpath $dir unless -d $dir;

    my $url = $self->{arg};
    {
        my $g = pushd $dir;
        $self->git->submodule_add($url);
    }
    my $submodule_path = do {
        my $basename = basename $url;
        $basename =~ s/\.git$//;
        catdir $dir, $basename;
    };

    my @pm_files = $self->_pm_files($submodule_path);

    for my $pm_file (@pm_files) {
        my $dirname = dirname $pm_file;
        my $lib_dir = catdir("lib", $dirname);
        mkpath $lib_dir unless -d $lib_dir;
        {
            my $g = pushd $lib_dir;
            my @up = splitdir $lib_dir;
            my $relative_pm_file
                = join("/", ("..") x scalar(@up)) . "/$submodule_path/lib/$pm_file";
            my $basename = basename $pm_file;
            symlink $relative_pm_file, $basename
                or die "symlink '$relative_pm_file' => '$basename': $!\n";
        }
    }
    warn "Successfully created and symlinked $submodule_path\n";
}

sub _pm_files {
    my ($self, $submodule_path) = @_;
    my @pm_files;
    {
        my $g = pushd "$submodule_path/lib";
        find sub {
            my $name = $File::Find::name;
            $name =~ s{^\./}{};
            push @pm_files, $name if $name =~ m{\.pm$};
        }, ".";
    }
    return @pm_files;
}


sub delete {
    my ($self, $root_dir) = @_;
    if ($self->git->version < 1.008005) {
        die "only git v1.8.5 or above supports git submodule deinit\n";
    }

    my $submodule_path;
    my $arg = $self->{arg};
    my $dir = $self->{dir};
    if ($arg =~ m/^$dir/ && -d $arg) {
        $submodule_path = $arg;
    } elsif (-d "$dir/$arg") {
        $submodule_path = "$dir/$arg";
    } elsif ($arg =~ m{::}) {
        my $try = $arg =~ s/::/-/gr;
        $submodule_path = "$dir/$try" if -d "$dir/$try";
    } else {
        my $try = basename $arg;
        $try =~ s/\.git$//;
        $submodule_path = "$dir/$try" if -d "$dir/$try";
    }

    $submodule_path or die "Cannot find submodule '$arg'\n";

    my @pm_files = $self->_pm_files($submodule_path);

    $self->git->submodule_delete($submodule_path);
    if (-d ".git/modules/$submodule_path") {
        rmtree ".git/modules/$submodule_path";
    }

    for my $pm_file (@pm_files) {
        my $link = catfile("lib", $pm_file);
        unlink $link if -l $link;
    }

    warn "Successfully deleted $submodule_path\n";
}



1;
__END__

=encoding utf-8

=head1 NAME

App::GitSubmoduleDep - manage module dependencies by git submodule + symlink

=head1 SYNOPSIS

    > git-submodule-dep git://github.com/foo/Module-Name.git
    > git-submodule-dep --delete Module::Name

=head1 DESCRIPTION

App::GitSubmoduleDep helps you manage module dependencies.
If your dependencies are not in cpan but in some git repository
(eg: Github Enterprise), it's difficult to manage them.

This module helps you manage them by git submodule + symlink.

=head1 THANKS TO

L<ytnobody|https://github.com/ytnobody>, who taught me this technique

=head1 LICENSE

Copyright (C) Shoichi Kaji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Shoichi Kaji E<lt>skaji@cpan.orgE<gt>

=cut

