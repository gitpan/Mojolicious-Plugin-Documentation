package Mojolicious::Plugin::Documentation;
use Mojo::Base 'Mojolicious::Plugin';
use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

use Pod::Simple::Search;
use Pod::Simple::HTML;
use Mojo::Util qw/slurp url_unescape/;

sub register {
    my ( $self, $app ) = @_;

    my $base = catdir( dirname( __FILE__ ), 'Documentation' );
    push @{ $app->renderer->paths }, catdir( $base, 'template' );
    push @{ $app->static->paths },   catdir( $base, 'public' );

    my $clean = sub {
        my ( $s, $more ) = @_;
          $$s =~ s!(?://)+|(?:///)+!/!g;
          $$s =~ s!/*$!!g;
          $$s =~ s!^/*!!g if $more;
    };

    $app->helper( documentation => sub {
        my ( $c, %args ) = @_;
        my $r = $app->routes;
        $args{ '-root' } //= $self->_root; $clean->( \$args{ '-root' }, 1 );
        $args{ '-base' } //= $r->namespaces->[0];
        $self->_root( $args{ '-root' } );
        my $package = $args{ '-base' };
        my $options = { pod => join( '::', grep { defined } ( $package ) ), format => 'html' };
        my @route;
        my @children = @{ $r->children };
        for my $child ( @children ) {
            next if exists $child->pattern->defaults->{cb};
            my $pattern = $child->pattern->pattern;
               $pattern //= '/';
            my %default = %{ $child->pattern->defaults };
               $default{controller} = ucfirst $default{controller};
               $default{action} //= '';
            my %options = %{ $options };
            $pattern = join '/', "/$args{ '-root' }", $pattern; $clean->( \$pattern );
            $options{pod} = join '::', grep { defined } $package, $default{controller};
            $options{id} = $default{action};
            my $route = { -pattern => [ $pattern => { %options } => [ pod => qr/[^.]+/ ] => \&pod ] };
            push @route, $route;
        }

        my $pattern = join '/', "/$args{ '-root' }", ':pod'; $clean->( \$pattern );
        my $route = { -pattern => [ $pattern => $options => [ pod => qr/[^.]+/ ] => \&pod ], -name => 'documentation' };
        push @route, $route;

        for my $route ( @route ) {
            my $r = $r->any( @{ $route->{ '-pattern' } } );
            $r->name( $route->{ '-name' } ) if $route->{ '-name' };
        }
    } );
    $app->helper( __root_ => sub { shift; $self->_root( @_ ) } );
    $app->helper( __path_ => sub { shift; $self->_path( @_ ) } );
}

has _root => sub { 'docs' };
has _base => sub {
    my $self = shift;
    my $base = $FindBin::Bin;
    while ( $base and not -e "$base/lib" ) { $base =~ s"/[^/]+/?$""; }
    return $base;
};

sub _path {
    my ( $self, @path ) = @_;
    my ( $base ) = ( $self->_base );
    @path = map { $_ =~ s/^\///; $_ =~ s/\/$//; $_ } @path;
    $base =~ s/\/$//;
    return join '/', $base, @path;
}

sub pod {
    my $self = shift;
    my %args = $self->args;
    $self->render( json => { pod => \%args } );
    my $pod = new Pod::Simple::HTML;
    my $out; $pod->output_string( \$out );
    my $in = Pod::Simple::Search->new->find( $args{pod}
        , $self->__path_( $self->__root_ )
        , $self->__path_( 'docs' )
        , $self->__path_( 'pods' )
        , $self->__path_( 'pod' )
        , $self->__path_( 'doc' )
        , @INC
    );
    $pod->parse_string_document( slurp $in ) if $in and -e $in;
    $self->res->headers->content_type( 'text/html' );
    $out =~ s#http://search.cpan.org/perldoc\?([^'"]+)#url_unescape("/docs/$1")#eg;
    $self->render( layout => 'documentation', template => 'pod', pod => $out, name => $args{pod}, file => $in );
    $self->rendered( 200 );
}

# ABSTRACT: A work in progress; intended to be a better documentation renderer then PODRenderer (don't use this for now).
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mojolicious::Plugin::Documentation - A work in progress; intended to be a better documentation renderer then PODRenderer (don't use this for now).

=head1 VERSION

version 0.03

=head1 DO NOT USE THIS

I'm still working on it.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/sharabash/mojolicious-plugin-documentation/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/sharabash/mojolicious-plugin-documentation>

  git clone git://github.com/sharabash/mojolicious-plugin-documentation.git

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 CONTRIBUTOR

Nour Sharabash <nour.sharabash@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
