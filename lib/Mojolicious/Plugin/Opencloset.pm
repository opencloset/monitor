package Mojolicious::Plugin::Opencloset;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app, $conf ) = @_;
    $app->helper( error => \&_error );
}

sub _error {
    my ( $self, $status, $error ) = @_;

    app->log->error( $error->{str} );

    no warnings 'experimental';
    my $template;
    given ($status) {
        $template = 'bad_request' when 400;
        $template = 'not_found' when 404;
        $template = 'exception' when 500;
        default { $template = 'unknown' }
    }

    $self->respond_to(
        json => { status => $status, json => { error => $error || q{} } },
        html => {
            status   => $status,
            error    => $error->{str} || q{},
            template => $template
        },
    );

    return;
}

1;

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Opencloset - provide helpers for opencloset

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'opencloset';

=head1 HELPERS

=head2 error

    get '/foo' => sub {
        my $self = shift;
        my $required = $self->param('something');
        return $self->error(400, 'oops wat the..') unless $required;
    } => 'foo';

=cut
