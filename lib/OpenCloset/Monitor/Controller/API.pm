package OpenCloset::Monitor::Controller::API;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use Encode 'decode_utf8';
use HTTP::Tiny;
use Mojo::JSON qw/decode_json j/;
use OpenCloset::Constants::Status
    qw/$RESERVATED $NOT_VISITED $NOT_RENTAL $NO_SIZE $VISITED $MEASUREMENT $SELECT $FITTING_ROOM1 $FITTING_ROOM2 $FITTING_ROOM3 $FITTING_ROOM4 $FITTING_ROOM5 $FITTING_ROOM6 $FITTING_ROOM7 $FITTING_ROOM8 $FITTING_ROOM9 $FITTING_ROOM10 $FITTING_ROOM11 $FITTING_ROOM12 $FITTING_ROOM13 $FITTING_ROOM14 $FITTING_ROOM15 $REPAIR $BOX/;

use OpenCloset::Constants::Category
    qw/%REVERSE_MAP $LABEL_JACKET $LABEL_PANTS $LABEL_SHIRT $LABEL_TIE $LABEL_SHOES $LABEL_SKIRT $LABEL_BLOUSE $LABEL_BELT/;

our $PREFIX = 'opencloset:storage';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 update_order

    # PUT /api/orders/:order_id?status_id=:status_id&bestfit=:bestfit&pants=:pants

=over params

=item status_id

C<$OpenCloset::Monitor::Status::STATUS_*>

=item bestfit

0 or 1

=item pants

90 ~ 120

=back

=cut

sub update_order {
    my $self      = shift;
    my $order_id  = $self->param('order_id');
    my $status_id = $self->param('status_id');
    my $bestfit   = $self->param('bestfit');
    my $pants     = $self->param('pants');
    my $does_wear = $self->param('does_wear');

    my $queries = { id => $order_id };
    $queries->{status_id} = $status_id if defined $status_id;
    $queries->{bestfit}   = $bestfit   if defined $bestfit;
    $queries->{pants}     = $pants     if defined $pants;
    $queries->{does_wear} = $does_wear if defined $does_wear;

    my $redis = $self->redis;
    $redis->hdel( "$PREFIX:room",   $order_id );
    $redis->hdel( "$PREFIX:select", $order_id );

    my $opencloset = $self->app->config->{opencloset};
    my $cookie     = $self->app->_auth_opencloset;
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookie );
    my $params     = $http->www_form_urlencode($queries);
    my $url        = $opencloset->{uri} . "/api/order/$order_id.json?$params";
    my $res        = $http->request( 'PUT', $url );
    return $self->error( 500, { str => 'Failed to update order' } )
        unless $res->{success};

    ## 주문서의 bestfit 업데이트는 staff 로 부터 이벤트가 오지 않는다.
    ## does_wear 또한 이벤트가 발생되지 않는다.
    ## 해서 스스로 발생
    if ( defined $queries->{bestfit} or defined $queries->{does_wear} ) {
        my $channel = $self->app->redis_channel;
        my $extra   = decode_json( $res->{content} );
        my $data    = { extra => $extra };
        $data->{sender}   = 'order';
        $data->{order_id} = $extra->{id};
        $data->{from}     = $data->{to} = $extra->{status_id};
        $self->redis->publish( "$channel:order" => decode_utf8( j($data) ) );
    }

    ## pants 는 주문서뿐만 아니라 실제 사용자정보도 업데이트 해야 한다
    if ( my $pants = $queries->{pants} ) {
        my $order   = $self->DB->resultset('Order')->find( { id => $order_id } );
        my $user    = $order->user;
        my $user_id = $user->id;
        my $url     = $opencloset->{uri} . "/api/user/$user_id.json";
        my $res     = $http->request(
            'PUT', $url,
            {
                content => $http->www_form_urlencode( { pants => $pants } ),
                headers => { 'content-type' => 'application/x-www-form-urlencoded' }
            }
        );
        $self->log->error( 'Failed to patch user pants: ' . $res->{reason} )
            unless $res->{success};
    }

    $self->render( text => decode_utf8( $res->{content} ) );
}

=head2 update_user

    # PUT /api/users/:user_id

=over

=item category

=back

=cut

sub update_user {
    my $self    = shift;
    my $user_id = $self->param('user_id');

    my $v = $self->validation;
    $v->optional('category')->in(
        $LABEL_JACKET, $LABEL_PANTS, $LABEL_SHIRT,  $LABEL_TIE,
        $LABEL_SHOES,  $LABEL_SKIRT, $LABEL_BLOUSE, $LABEL_BELT,
    );

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $user = $self->DB->resultset('User')->find( { id => $user_id } );
    return $self->error( 400, { str => "Not found user: $user_id" } ) unless $user;

    my $user_info = $user->user_info;
    my $category = $REVERSE_MAP{ $v->param('category') } || '';

    return $self->render( json => { $user_info->get_columns } ) unless $category;

    my $pre_category = $user_info->pre_category;
    my %categories;
    map { $categories{$_}++ } split /,/, $pre_category;

    if ( $categories{$category} ) {
        delete $categories{$category};
    }
    else {
        $categories{$category}++;
    }

    my %params;
    $params{pre_category} = join( ',', keys %categories );

    my $opencloset = $self->app->config->{opencloset};
    my $cookie     = $self->app->_auth_opencloset;
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookie );
    my $url        = $opencloset->{uri} . "/api/user/$user_id.json";
    my $res        = $http->request(
        'PUT', $url,
        {
            content => $http->www_form_urlencode( {%params} ),
            headers => { 'content-type'           => 'application/x-www-form-urlencoded' }
        }
    );

    return $self->error( 500, { str => 'Failed to update user' } ) unless $res->{success};

    $self->render( text => decode_utf8( $res->{content} ) );
}

=head2 address

    # GET /address?q=:query

=cut

sub address {
    my $self = shift;
    my $q = $self->param('q') || '';

    return $self->render( json => [] ) unless length $q > 1;

    my @or;
    if ( $q =~ /^[0-9\-]+$/ ) {
        $q =~ s/-//g;
        push @or, { 'user_info.phone' => { like => "%$q%" } };
    }
    elsif ( $q =~ /^[a-zA-Z0-9_\-]+/ ) {
        if ( $q =~ /\@/ ) {
            push @or, { email => { like => "%$q%" } };
        }
        else {
            push @or, { email => { like => "%$q%" } };
            push @or, { name  => { like => "%$q%" } };
        }
    }
    elsif ( $q =~ m/^[ㄱ-힣]+$/ ) {
        push @or, { name => { like => "$q%" } };
    }

    my $rs = $self->DB->resultset('User')
        ->search( { -or => [@or] }, { join => 'user_info', rows => 5 } );

    my @address;
    while ( my $row = $rs->next ) {
        my %columns = ( $row->get_columns, phone => $row->user_info->phone );

        delete $columns{password};
        push @address, {%columns};
    }

    return $self->render( json => [@address] );
}

=head2 create_sms

    # sms.create
    # POST /sms

=cut

sub create_sms {
    my $self = shift;

    my $v = $self->validation;
    $v->required('to')->like(qr/^\d+$/);
    $v->required('text')->like(qr/^(\s|\S)+$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $to   = $v->param('to');
    my $text = $v->param('text');
    my $sms  = $self->DB->resultset('SMS')
        ->create( { from => $self->app->config->{sms_from}, to => $to, text => $text } );

    return $self->error( 500, { str => 'Failed to create a new sms' } ) unless $sms;

    $self->render( json => { $sms->get_columns } );
}

=head2 update_brain

    # brain.update
    # PUT /brain

=over parameters

=item k

=item v

=back

=cut

sub update_brain {
    my $self = shift;

    my $v = $self->validation;
    $v->required('k')->like(qr/^[a-z]+$/);
    $v->required('v');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $key   = $v->param('k');
    my $value = $v->param('v');

    my $redis = $self->redis;
    $redis->hset( "$PREFIX", $key, $value );
    $self->render( json => { data => { $key => $value } } );
}

=head2 target_dt

    # target_date
    GET /target_date

=cut

sub target_dt {
    my $self = shift;

    my $origin = $self->req->headers->header('origin');
    $self->res->headers->header( 'Access-Control-Allow-Origin' => $origin );

    my $target_date = $self->target_date;
    $self->render( json => { ymd => $target_date->ymd, epoch => $target_date->epoch } );
}

=head2 cors

    OPTIONS /target_date

=cut

sub cors {
    my $self = shift;

    my $origin = $self->req->headers->header('origin');
    my $method = $self->req->headers->header('access-control-request-method');

    # return $self->error( 400, "Not Allowed Origin: $origin" )
    #     unless $origin =~ m/theopencloset\.net/;

    $self->res->headers->header( 'Access-Control-Allow-Origin'  => $origin );
    $self->res->headers->header( 'Access-Control-Allow-Methods' => $method );
    $self->respond_to( any => { data => '', status => 200 } );
}

our @AVAILABLE_STATUS = (
    $RESERVATED,     $NOT_VISITED,    $NOT_RENTAL,     $NO_SIZE,        $VISITED,
    $MEASUREMENT,    $SELECT,         $FITTING_ROOM1,  $FITTING_ROOM2,  $FITTING_ROOM3,
    $FITTING_ROOM4,  $FITTING_ROOM5,  $FITTING_ROOM6,  $FITTING_ROOM7,  $FITTING_ROOM8,
    $FITTING_ROOM9,  $FITTING_ROOM10, $FITTING_ROOM11, $FITTING_ROOM12, $FITTING_ROOM13,
    $FITTING_ROOM14, $FITTING_ROOM15, $REPAIR,         $BOX
);

=head2 status

    GET /api/status?available

C<available> param 이 있으면 사용중인 탈의실과 예약된 탈의실을 제외하고 응답.
그 외에는 모든 상태목록을 응답.

=cut

sub status {
    my $self      = shift;
    my $available = defined $self->param('available');

    my %except;
    if ($available) {
        my $orders
            = $self->DB->resultset('Order')
            ->search( { status_id => { -in => [$FITTING_ROOM1 .. $FITTING_ROOM15] } },
            undef );

        while ( my $order = $orders->next ) {
            $except{ $order->status_id }++;
        }
    }

    for my $status ( $FITTING_ROOM1 .. $FITTING_ROOM15 ) {
        my $room_no = $status - 19;
        next if $except{$status};

        my $order = $self->prev_order( $room_no, $SELECT );
        $except{$status}++ if $order;
    }

    my @status;
    for my $s (@AVAILABLE_STATUS) {
        next if $except{$s};
        push @status,
            { value => $s, text => $OpenCloset::Constants::Status::LABEL_MAP{$s} };
    }

    $self->res->headers->header( 'Access-Control-Allow-Origin' => '*' );
    $self->render( json => \@status );
}

1;
