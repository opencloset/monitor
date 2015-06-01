package OpenCloset::Monitor::Controller::API;
use Mojo::Base 'Mojolicious::Controller';

use HTTP::Tiny;
use MIME::Base64;
use Encode 'decode_utf8';

# PUT /api/orders/:id?status_id=17

=head1 METHODS

=head2 order

    # PUT /api/orders/:order_id?status_id=:status_id

=cut

sub order {
    my $self      = shift;
    my $order_id  = $self->param('order_id');
    my $status_id = $self->param('status_id');

    my $opencloset    = $self->app->config->{opencloset};
    my $authorization = 'Basic '
        . encode_base64( "$opencloset->{username}:$opencloset->{secret}", '' );

    my $http = HTTP::Tiny->new( timeout => 3 );
    my $params = $http->www_form_urlencode(
        { id => $order_id, status_id => $status_id } );
    my $res = $http->request(
        'PUT',
        $opencloset->{uri} . "/api/order/$order_id.json?$params",
        { headers => { Authorization => $authorization } }
    );

    $self->render( text => decode_utf8( $res->{content} ) );
}


1;
