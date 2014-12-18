package OpenCloset::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use DateTime::Tiny;
use Mojo::Redis2;

sub register {
    my ( $self, $app, $conf ) = @_;
    $app->helper( error         => \&error );
    $app->helper( age           => \&age );
    $app->helper( order_flatten => \&order_flatten );
    $app->helper( redis         => \&redis );
}

sub order_flatten {
    my ( $self, $order ) = @_;
    my $user      = $order->user;
    my $user_info = $user->user_info;
    my %columns   = $order->get_columns;
    $columns{user}      = { $user->get_columns };
    $columns{user_info} = { $user->get_columns };
    delete $columns{user}{password};
    delete $columns{user_info}{password};
    return {%columns};
}

sub error {
    my ( $self, $status, $error ) = @_;

    $self->app->log->error( $error->{str} );

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
            status => $status,
            error => $error->{str} || q{},
            template => $template
        },
    );

    return;
}

sub age {
    my ( $self, $birth ) = @_;
    my $now = DateTime::Tiny->now;
    return $now->year - $birth;
}

sub redis {
    my $self = shift;

    $self->stash->{redis} ||= do {
        my $log   = $self->app->log;
        my $redis = Mojo::Redis2->new;    # just use `redis://localhost:6379`
        $redis->on(
            error => sub {
                $log->error("[REDIS ERROR] $_[1]");
            }
        );

        $redis;
    };
}

1;

=pod

=encoding utf8

=head1 NAME

OpenCloset::Plugin::Helpers - provide helpers for opencloset

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'OpenCloset::Plugin::Helpers';

=head1 HELPERS

=head2 error

    get '/foo' => sub {
        my $self = shift;
        my $required = $self->param('something');
        return $self->error(400, 'oops wat the..') unless $required;
    } => 'foo';

=cut
