package OpenCloset::Monitor::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 auth

    under /

=cut

sub auth {
    my $self    = shift;
    my $address = $self->remote_addr;
    my $method  = $self->tx->req->method;

    return 1 if $method ne 'GET';
    unless ( $self->app->ranges->find($address) ) {
        $self->app->log->warn("denied address: $address");
        $self->render( text => 'Permission denied' );
        return;
    }
    return 1;
}

1;
