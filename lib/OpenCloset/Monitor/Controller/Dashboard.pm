package OpenCloset::Monitor::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Brain;
use OpenCloset::Status;

use Encode 'decode_utf8';
use Mojo::JSON 'j';

has DB => sub { shift->app->DB };

sub index {
    my $self = shift;
    my $rs
        = $self->DB->resultset('Order')
        ->search(
        { status_id => { -in  => [@OpenCloset::Status::ACTIVE_STATUS] } },
        { order_by  => { -asc => 'update_date' } } );

    my ( @visit, @measure, @select, @undress, @repair, @boxing, @payment );
    while ( my $order = $rs->next ) {
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
        $active[$n] = $brain->{data}{orders}{room}{ $order->id } if $order;
        $room[$n] = $order;
    }

    $brain->{data}{orders}{room} = {} unless @active;
    $self->stash( rooms => [@room], active => [@active] );
}

sub create_room {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{orders}{room}{$order_id} = 1;

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j(
                {
                    sender => 'active.room',
                    data   => $brain->{data}{orders}{room}
                }
            )
        )
    );
    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
}

sub delete_room {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    delete $brain->{data}{orders}{room}{$order_id};

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j(
                {
                    sender => 'active.room',
                    data   => $brain->{data}{orders}{room}
                }
            )
        )
    );
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
}

sub select {
    my $self = shift;

    my $rs = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_SELECT },
        { order_by  => { -asc => 'update_date' } }
    );

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{orders} = {} unless $rs->count;
    my @active = keys %{ $brain->{data}{orders}{select} ||= {} };
    $self->stash( orders => $rs, active => [@active] );
}

sub create_select {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{orders}{select}{$order_id} = 1;

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j(
                {
                    sender => 'active.select',
                    data   => $brain->{data}{orders}{select}
                }
            )
        )
    );

    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
}

sub delete_select {
    my $self     = shift;
    my $order_id = $self->param('order_id');

    my $brain = OpenCloset::Brain->new;
    delete $brain->{data}{orders}{select}{$order_id};

    my $channel = $self->app->redis_channel;
    $self->redis->publish(
        "$channel:active" => decode_utf8(
            j(
                {
                    sender => 'active.select',
                    data   => $brain->{data}{orders}{select}
                }
            )
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
        $room_active[$n] = $brain->{data}{orders}{room}{ $order->id }
            if $order;
        $room[$n] = $order;
    }

    my @select_active = keys %{ $brain->{data}{orders}{select} ||= {} };

    $brain->{data}{orders}{room} = {} unless @room_active;
    $brain->{data}{orders} = {} unless $rs->count;

    my @repair = $self->DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_REPAIR },
        { order_by  => { -asc => 'update_date' } }
    );

    $self->stash(
        orders        => $rs,
        rooms         => [@room],
        room_active   => [@room_active],
        select_active => [@select_active],
        repair        => [@repair]
    );
}

1;
