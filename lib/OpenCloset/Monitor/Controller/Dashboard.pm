package OpenCloset::Monitor::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Monitor::Status qw/$STATUS_FITTING_ROOM1 $STATUS_FITTING_ROOM15/;

use DateTime;
use DateTime::Format::ISO8601;
use Encode 'decode_utf8';
use Mojo::JSON 'j';

our $PREFIX = 'opencloset:storage';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    # index
    GET /

=cut

sub index {
    my $self = shift;
    my $rs
        = $self->DB->resultset('Order')
        ->search(
        { status_id => { -in  => [@OpenCloset::Monitor::Status::ACTIVE_STATUS] } },
        { order_by  => { -asc => 'update_date' } } );

    my ( @visit, @measure, @select, @undress, @repair, @boxing, @payment );
    while ( my $order = $rs->next ) {
        ## 임시로 skip
        next unless $order->booking;
        next unless $order->booking->date;
        next if $order->online;

        my $status_id = $order->status_id;
        use experimental qw/ smartmatch /;
        given ($status_id) {
            when ($OpenCloset::Monitor::Status::STATUS_VISIT) { push @visit, $order }
            when ($OpenCloset::Monitor::Status::STATUS_MEASURE) {
                push @measure, $order
            }
            when ($OpenCloset::Monitor::Status::STATUS_SELECT) { push @select, $order }
            when (
                [
                    $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1 ..
                        $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM15
                ]
                )
            {
                push @undress, $order
            }
            when ($OpenCloset::Monitor::Status::STATUS_REPAIR) { push @repair, $order }
            when ($OpenCloset::Monitor::Status::STATUS_BOXING) { push @boxing, $order }
            when ($OpenCloset::Monitor::Status::STATUS_BOXED)  { push @boxing, $order }
            when ($OpenCloset::Monitor::Status::STATUS_PAYMENT) {
                push @payment, $order
            }
            default {
                $self->app->log->warn("Unknown status: $status_id, $order");
            }
        }
    }

    $self->respond_to(
        json => sub {
            my @orders;
            while ( my $order = $rs->next ) {
                push @orders, $self->order_flatten($order);
            }
            return [@orders];
        },
        html => sub {
            $self->stash(
                orders => [
                    [@visit], [@measure], [@select], [@undress],
                    [@repair], [@boxing], [@payment]
                ],
                target_date => $self->target_date,
            );
        }
    );
}

=head2 create_active

    POST /active

    key=room&order_id=1862

=head3 params

=over

=item key

=over

=item room

=item select

=back

=item order_id

=item room_no

=back

=cut

sub create_active {
    my $self = shift;

    my $v = $self->validation;
    $v->required('key');
    $v->optional('order_id');
    $v->optional('room_no');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $key      = $v->param('key');
    my $order_id = $v->param('order_id');
    my $room_no  = $v->param('room_no');
    my $value    = $order_id || $room_no;

    $self->redis->hset( "$PREFIX:$key", $value, 1 );

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => "active.$key", order_id => $order_id, room_no => $room_no } )
        )
    );

    $self->render( text => "Successfully posted $key($value)", status => 201 );
}


=head2 delete_active

    DELETE /active/:value

=cut

sub delete_active {
    my $self  = shift;
    my $value = $self->param('value');

    my $v = $self->validation;
    $v->required('key');

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $key = $v->param('key');
    $self->redis->hdel( "$PREFIX:$key", $value );

    my ( $order_id, $room_no );
    if ( $key eq 'select' ) {
        $order_id = $value;
    }
    else {
        ## 'room' or 'refresh'
        $room_no = $value;
    }

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => "active.$key", order_id => $order_id, room_no => $room_no } )
        )
    );

    $self->render( text => "Successfully deleted $key($value)", status => 201 );
}

=head2 room

    # rooms
    GET /room

=cut

sub room {
    my $self  = shift;
    my $redis = $self->redis;

    my $orders
        = $self->DB->resultset('Order')
        ->search(
        { status_id => { -between => [$STATUS_FITTING_ROOM1, $STATUS_FITTING_ROOM15] } }
        );

    my %rooms;
    while ( my $order = $orders->next ) {
        my $room_no   = $order->status_id - 19;
        my $user      = $order->user;
        my $user_info = $user->user_info;
        $rooms{$room_no}         = { $order->get_columns };
        $rooms{$room_no}{name}   = $user->name;
        $rooms{$room_no}{gender} = $user_info->gender;
    }

    my @rooms;
    for my $room_no ( 1 .. 15 ) {
        push @rooms, $rooms{$room_no} || { name => '', gender => '' };
    }

    $self->respond_to(
        json => { json => { rooms => \@rooms } },
        html => sub    { $self->render }
    );
}

=head2 select

    # select
    GET /select

=cut

sub select {
    my $self  = shift;
    my $redis = $self->redis;

    my $rs
        = $self->DB->resultset('Order')
        ->search( { status_id => $OpenCloset::Monitor::Status::STATUS_SELECT },
        { order_by => { -asc => 'update_date' } } );

    $redis->del("$PREFIX:select") unless $rs->count;
    my $active = $redis->hkeys("$PREFIX:select");
    $self->stash( orders => $rs, active => $active );
}

=head2 preparation

    # preparation
    GET /preparation

=cut

sub preparation {
    my $self = shift;

    my %bestfit;
    my $parser = $self->DB->storage->datetime_parser;
    my $attr   = {
        select   => ['user_info.gender', { count => 'bestfit' }],
        as       => [qw/gender cnt/],
        join     => ['booking',          { user  => 'user_info' }],
        group_by => 'user_info.gender'
    };
    my $start = DateTime->now;
    my $end   = $start->clone;
    $start->set( hour => 0, minute => 0, second => 0 );
    $end->set( hour => 23, minute => 59, second => 59 );

    my $today = $self->DB->resultset('Order')->search(
        {
            bestfit        => 1,
            'booking.date' => {
                -between =>
                    [$parser->format_datetime($start), $parser->format_datetime($end),]
            }
        },
        $attr
    );

    while ( my $row = $today->next ) {
        my $gender = $row->get_column('gender');
        my $cnt    = $row->get_column('cnt');
        $bestfit{today}{$gender} = $cnt;
    }

    $start->add( days => -( $start->wday ) );
    my $week = $self->DB->resultset('Order')->search(
        {
            bestfit        => 1,
            'booking.date' => {
                -between =>
                    [$parser->format_datetime($start), $parser->format_datetime($end),]
            }
        },
        $attr
    );
    while ( my $row = $week->next ) {
        my $gender = $row->get_column('gender');
        my $cnt    = $row->get_column('cnt');
        $bestfit{week}{$gender} = $cnt;
    }

    $self->render( bestfit => {%bestfit}, waiting => $self->app->_waiting_list );
}

=head2 repair

    # repair
    GET /repair

=cut

sub repair {
    my $self = shift;

    my $waiting = $self->app->_waiting_list;
    my $redis   = $self->redis;
    my $rs
        = $self->DB->resultset('Order')
        ->search( { status_id => $OpenCloset::Monitor::Status::STATUS_REPAIR },
        { order_by => { -asc => 'update_date' } } );

    my $done = $redis->hgetall("$PREFIX:repair");
    $self->respond_to(
        json => { json => { waiting => $waiting } },
        html => sub {
            $self->render( orders => $rs, waiting => $waiting, done => {@$done} );
        }
    );
}

=head2 online

    # online
    GET /online

=cut

sub online {
    my $self = shift;

    ## 각 상태별 주문서를 남녀별로
    my $rs = $self->DB->resultset('Order')->search(
        {
            status_id => { -in => [@OpenCloset::Monitor::Status::ACTIVE_STATUS] },
            online    => 1,
        },
        { order_by => { -asc => 'update_date' }, join => 'booking' }
    );

    my ( @visit, @measure, @select, @undress, @repair, @boxing, @payment );
    while ( my $order = $rs->next ) {
        my $status_id = $order->status_id;
        use experimental qw/ smartmatch /;
        given ($status_id) {
            when ($OpenCloset::Monitor::Status::STATUS_VISIT) { push @visit, $order }
            when ($OpenCloset::Monitor::Status::STATUS_MEASURE) {
                push @measure, $order
            }
            when ($OpenCloset::Monitor::Status::STATUS_SELECT) { push @select, $order }
            when (
                [
                    $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1 ..
                        $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM15
                ]
                )
            {
                push @undress, $order
            }
            when ($OpenCloset::Monitor::Status::STATUS_REPAIR) { push @repair, $order }
            when ($OpenCloset::Monitor::Status::STATUS_BOXING) { push @boxing, $order }
            when ($OpenCloset::Monitor::Status::STATUS_BOXED)  { push @boxing, $order }
            when ($OpenCloset::Monitor::Status::STATUS_PAYMENT) {
                push @payment, $order
            }
            default {
                $self->app->log->warn("Unknown status: $status_id, $order");
            }
        }
    }

    $self->render(
        all    => $rs->reset,
        groups => [
            [@visit], [@measure], [@select], [@undress],
            [@repair], [@boxing], [@payment]
        ]
    );
}

1;
