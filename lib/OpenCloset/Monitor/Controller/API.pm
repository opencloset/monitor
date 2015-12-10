package OpenCloset::Monitor::Controller::API;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Encode 'decode_utf8';
use HTTP::CookieJar;
use HTTP::Tiny;
use Path::Tiny;

use OpenCloset::Brain;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 order

    # PUT /api/orders/:order_id?status_id=:status_id&bestfit=:bestfit&pants=:pants

=over params

=item status_id

C<$OpenCloset::Status::STATUS_*>

=item bestfit

0 or 1

=item pants

90 ~ 120

=back

=cut

sub order {
    my $self      = shift;
    my $order_id  = $self->param('order_id');
    my $status_id = $self->param('status_id');
    my $bestfit   = $self->param('bestfit');
    my $pants     = $self->param('pants');

    my $queries = { id => $order_id };
    $queries->{status_id} = $status_id if defined $status_id;
    $queries->{bestfit}   = $bestfit   if defined $bestfit;
    $queries->{pants}     = $pants     if defined $pants;

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

    ## pants 는 주문서뿐만 아니라 실제 사용자정보도 업데이트 해야 한다
    if ( my $pants = $queries->{pants} ) {
        my $order = $self->DB->resultset('Order')->find( { id => $order_id } );
        my $user = $order->user;
        my $user_id = $user->id;
        my $url     = $opencloset->{uri} . "/api/user/$user_id.json";
        my $res     = $http->request(
            'PUT', $url,
            {
                content => $http->www_form_urlencode( { pants => $pants } ),
                headers =>
                    { 'content-type' => 'application/x-www-form-urlencoded' }
            }
        );
        $self->log->error( 'Failed to patch user pants: ' . $res->{reason} )
            unless $res->{success};
    }

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

        ## 성공일때 응답코드가 302 인데, 이는 실패했을때와 마찬가지이다.
        if ( $res->{status} == 302 && $res->{headers}{location} eq '/' ) {
            $cookie->spew( join "\n", $cookiejar->dump_cookies );
        }
        else {
            $self->app->log->error("Failed Authentication to Opencloset");
            $self->app->log->error("$res->{status} $res->{reason}");
        }
    }

    return $cookiejar;
}

1;
