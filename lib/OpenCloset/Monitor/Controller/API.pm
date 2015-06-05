package OpenCloset::Monitor::Controller::API;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Encode 'decode_utf8';
use HTTP::CookieJar;
use HTTP::Tiny;
use Path::Tiny;

use OpenCloset::Brain;

=head1 METHODS

=head2 order

    # PUT /api/orders/:order_id?status_id=:status_id&bestfit=:bestfit

=over params

=item status_id

C<$OpenCloset::Status::STATUS_*>

=item bestfit

0 or 1

=back

=cut

sub order {
    my $self      = shift;
    my $order_id  = $self->param('order_id');
    my $status_id = $self->param('status_id');
    my $bestfit   = $self->param('bestfit');

    my $queries = { id => $order_id };
    $queries->{status_id} = $status_id if defined $status_id;
    $queries->{bestfit}   = $bestfit   if defined $bestfit;

    my $brain = OpenCloset::Brain->new;
    delete $brain->{data}{room}{$order_id};
    delete $brain->{data}{select}{$order_id};

    my $opencloset = $self->app->config->{opencloset};
    my $cookie     = $self->_auth_opencloset;
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookie );
    my $params     = $http->www_form_urlencode($queries);
    my $url        = $opencloset->{uri} . "/api/order/$order_id.json?$params";
    my $res        = $http->request( 'PUT', $url );
    return $self->error( 500, { str => 'Failed to update order' } )
        unless $res->{success};
    $self->render( text => decode_utf8( $res->{content} ) );
}

=head2 _auth_opencloset

=cut

sub _auth_opencloset {
    my $self = shift;

    my $opencloset = $self->app->config->{opencloset};
    my $cookie     = path( $opencloset->{cookie} )->touch;
    my $cookiejar  = HTTP::CookieJar->new->load_cookies( $cookie->lines );
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookiejar );

    my ($cookies) = $cookiejar->cookies_for( $opencloset->{uri} );
    my $expires   = $cookies->{expires};
    my $now       = DateTime->now->epoch;
    if ( !$expires || $expires < $now ) {
        my $email    = $opencloset->{email};
        my $password = $opencloset->{password};
        my $url      = $opencloset->{uri} . "/login";
        my $res      = $http->post_form( $url,
            { email => $email, password => $password, remember => 1 } );

        print "$res->{status} $res->{reason}\n";
        $cookie->spew( join "\n", $cookiejar->dump_cookies );

        ## 성공일때 응답코드가 302 인데, 이는 실패했을때와 마찬가지이다.
        unless ( $res->{success} ) {
            $self->app->log->error("Failed Authentication to Opencloset");
            $self->app->log->error("$res->{status} $res->{reason}");
        }
    }

    return $cookiejar;
}

1;
