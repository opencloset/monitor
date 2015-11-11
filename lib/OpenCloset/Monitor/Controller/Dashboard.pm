package OpenCloset::Monitor::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Brain;
use OpenCloset::Status;

use Encode 'decode_utf8';
use Mojo::JSON 'j';

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
        { status_id => { -in  => [@OpenCloset::Status::ACTIVE_STATUS] } },
        { order_by  => { -asc => 'update_date' } } );

    my ( @visit, @measure, @select, @undress, @repair, @boxing, @payment );
    while ( my $order = $rs->next ) {
        ## 임시로 skip, 22:00 는 온라인 대여자
        my $booking_date = $order->booking->date;
        next if $booking_date->hour == '22';

        my $status_id = $order->status_id;
        use experimental qw/ smartmatch /;
        given ($status_id) {
            when ($OpenCloset::Status::STATUS_VISIT) { push @visit, $order }
            when ($OpenCloset::Status::STATUS_MEASURE) {
                push @measure, $order
            }
            when ($OpenCloset::Status::STATUS_SELECT) { push @select, $order }
            when (
                [
                    $OpenCloset::Status::STATUS_FITTING_ROOM1 ..
                        $OpenCloset::Status::STATUS_FITTING_ROOM11
                ]
                )
            {
                push @undress, $order
            }
            when ($OpenCloset::Status::STATUS_REPAIR) { push @repair, $order }
            when ($OpenCloset::Status::STATUS_BOXING) { push @boxing, $order }
            when ($OpenCloset::Status::STATUS_BOXED)  { push @boxing, $order }
            when ($OpenCloset::Status::STATUS_PAYMENT) {
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
                ]
            );
        }
    );
}

=head2 room

    # rooms
    GET /room

=cut

sub room {
    my $self = shift;

    my $brain = OpenCloset::Brain->new;
    my ( @active, @room );
    for my $n ( 1 .. 11 ) {
        my $room;
        my $order = $self->DB->resultset('Order')->search(
            {
                status_id => $OpenCloset::Status::STATUS_FITTING_ROOM1 + $n - 1
            }
        )->next;
        $active[$n] = $brain->{data}{room}{ $order->id } if $order;
        $room[$n] = $order;
    }

    $brain->{data}{room} = {} unless @active;
    $self->stash( rooms => [@room], active => [@active] );
}

=head2 create_room

    POST /room

=cut

sub create_room {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{room}{$order_id} = 1;

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => 'active.room', order_id => $order_id } )
        )
    );
    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
}

=head2 delete_room

    DELETE /room/:order_id

=cut

sub delete_room {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    delete $brain->{data}{room}{$order_id};

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => 'active.room', order_id => $order_id } )
        )
    );
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
}

=head2 select

    # select
    GET /select

=cut

sub select {
    my $self = shift;

    my $rs = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_SELECT },
        { order_by  => { -asc => 'update_date' } }
    );

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{select} = {} unless $rs->count;
    my @active = keys %{ $brain->{data}{select} ||= {} };
    $self->stash( orders => $rs, active => [@active] );
}

=head2 create_select

    POST /select

=cut

sub create_select {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{select}{$order_id} = 1;

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => 'active.select', order_id => $order_id } )
        )
    );

    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
}

=head2 delete_select

    DELETE /select/:order_id

=cut

sub delete_select {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    delete $brain->{data}{select}{$order_id};

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j( { sender => 'active.select', order_id => $order_id } )
        )
    );
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
}

=head2 preparation

    # preparation
    GET /preparation

=cut

sub preparation {
    my $self = shift;

    my $brain = OpenCloset::Brain->new;
    my ( @room_active, @room );
    my $rs = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_SELECT },
        { order_by  => { -asc => 'update_date' } }
    );

    for my $n ( 1 .. 11 ) {
        my $room;
        my $order = $self->DB->resultset('Order')->search(
            {
                status_id => $OpenCloset::Status::STATUS_FITTING_ROOM1 + $n - 1
            }
        )->next;
        $room_active[$n] = $brain->{data}{room}{ $order->id } if $order;
        $room[$n] = $order;
    }

    my @select_active = keys %{ $brain->{data}{select} ||= {} };

    $brain->{data}{room}   = {} unless @room_active;
    $brain->{data}{select} = {} unless $rs->count;

    my @repair = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_REPAIR },
        { order_by  => { -asc => 'update_date' } }
    );

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
                -between => [
                    $parser->format_datetime($start),
                    $parser->format_datetime($end),
                ]
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
                -between => [
                    $parser->format_datetime($start),
                    $parser->format_datetime($end),
                ]
            }
        },
        $attr
    );
    while ( my $row = $week->next ) {
        my $gender = $row->get_column('gender');
        my $cnt    = $row->get_column('cnt');
        $bestfit{week}{$gender} = $cnt;
    }

    $self->stash(
        orders        => $rs,
        rooms         => [@room],
        room_active   => [@room_active],
        select_active => [@select_active],
        repair        => [@repair],
        bestfit       => {%bestfit}
    );
}

=head2 repair

    # repair
    GET /repair

=cut

sub repair {
    my $self = shift;

    my $counts = $self->DB->resultset('Order')->search(
        { status_id => { -in => [@OpenCloset::Status::ACTIVE_STATUS] } },
        {
            select =>
                ['status_id', 'user_info.gender', { count => 'status_id' }],
            as       => [qw/status_id gender cnt/],
            group_by => ['status_id', 'user_info.gender'],
            join     => { user => 'user_info' }
        }
    );

    ## SELECT status_id, ui.gender, COUNT(status_id) FROM `order` o JOIN user u ON o.user_id = u.id JOIN user_info ui ON u.id = ui.user_id GROUP BY status_id, ui.gender;
    my %counts;
    while ( my $row = $counts->next ) {
        my $status_id = $row->get_column('status_id');
        my $gender    = $row->get_column('gender');
        my $cnt       = $row->get_column('cnt');

        ## 탈의를 key 한개로 묶는다
        if (   $status_id >= $OpenCloset::Status::STATUS_FITTING_ROOM1
            && $status_id <= $OpenCloset::Status::STATUS_FITTING_ROOM11 )
        {
            $counts{$gender}{$OpenCloset::Status::STATUS_FITTING_ROOM1}
                += $cnt;
        }
        else {
            $counts{$gender}{$status_id} = $cnt;
        }
    }

    my $rs = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_REPAIR },
        { order_by  => { -asc => 'update_date' } }
    );

    $self->respond_to(
        json => { json => { counts => {%counts} } },
        html => sub {
            $self->render( orders => $rs, counts => {%counts} );
        }
    );
}

1;
