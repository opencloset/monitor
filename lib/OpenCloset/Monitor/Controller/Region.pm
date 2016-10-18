package OpenCloset::Monitor::Controller::Region;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw/j/;
use Directory::Queue;

use OpenCloset::Monitor::Status
    qw/$STATUS_SELECT $STATUS_REPAIR $STATUS_FITTING_ROOM1 $STATUS_BOXING/;

our $PREFIX = 'opencloset:storage';

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 selects

    # region.selects
    GET /region/selects

=cut

sub selects {
    my $self = shift;

    my $orders
        = $self->DB->resultset('Order')
        ->search( { status_id => $STATUS_SELECT, online => 0, },
        { order_by => { -asc => 'update_date' }, join => 'booking' } );

    my $redis = $self->redis;
    my $dirq = Directory::Queue->new( path => $self->config->{queue}{path} );

    my %suggestion;
    while ( my $order = $orders->next ) {
        my $user_id = $order->user_id;
        my $suggestion = $redis->hget( "$PREFIX:clothes", $user_id );
        unless ($suggestion) {
            $dirq->add($user_id);
            next;
        }

        $suggestion{$user_id} = j($suggestion);
    }

    $orders->reset;

    my $select_active = $redis->hkeys("$PREFIX:select");
    unless ( $orders->count ) {
        $redis->del("$PREFIX:select");
        $redis->del("$PREFIX:clothes");
    }

    my %emptyRoom;
    for my $n ( 1 .. 11 ) {
        my $order
            = $self->DB->resultset('Order')
            ->search( { status_id => $STATUS_FITTING_ROOM1 + $n - 1 }, { rows => 1 } )
            ->single;
        $emptyRoom{$n} = 1 unless $order;
    }

    while ( my $order = $orders->next ) {
        my $history = $self->history( { order_id => $order->id } )->next;
        next unless $history;

        delete $emptyRoom{ $history->room_no };
    }

    $orders->reset;

    $self->render(
        orders        => $orders,
        select_active => $select_active,
        suggestion    => \%suggestion,
        emptyRooms    => [keys %emptyRoom],
    );
}

=head2 rooms

    # region.rooms
    GET /region/rooms

=cut

sub rooms {
    my $self = shift;

    my $redis = $self->redis;
    my ( @active, @room );

    for my $n ( 1 .. 11 ) {
        my $room;
        my $order = $self->DB->resultset('Order')
            ->search( { status_id => $STATUS_FITTING_ROOM1 + $n - 1 } )->next;
        $active[$n] = $redis->hget( "$PREFIX:room", $n );
        $room[$n] = $order;
    }

    $redis->del("$PREFIX:room") unless @active;
    $self->render(
        rooms          => [@room],
        room_active    => [@active],
        refresh_active => { @{ $redis->hgetall("$PREFIX:refresh") } },
    );
}

=head2 repair

    GET /region/status/repair

=cut

sub status_repair {
    my $self = shift;

    my $redis = $self->redis;

    my @repair = $self->DB->resultset('Order')->search( { status_id => $STATUS_REPAIR },
        { order_by => { -asc => 'update_date' } } );

    my $boxing = $self->DB->resultset('Order')->search(
        { status_id => $STATUS_BOXING, online => 0, },
        { order_by => { -asc => 'update_date' } }
    )->count;

    $redis->del("$PREFIX:repair") unless @repair or $boxing;

    my $done = $redis->hgetall("$PREFIX:repair");
    $self->render( repair => [@repair], done => {@$done} );
}

=head2 boxed

    GET /region/status/boxing

=cut

sub status_boxing {
    my $self = shift;

    my @boxing = $self->DB->resultset('Order')->search(
        { status_id => $STATUS_BOXING, online => 0, },
        { order_by => { -asc => 'update_date' } }
    );

    $self->render( boxing => [@boxing] );
}

1;
