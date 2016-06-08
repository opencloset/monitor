package OpenCloset::Monitor::Controller::Region;
use Mojo::Base 'Mojolicious::Controller';

use Directory::Queue;

use OpenCloset::Monitor::Status
    qw/$STATUS_SELECT $STATUS_REPAIR $STATUS_FITTING_ROOM1 $STATUS_BOXING/;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 selects

    # region.selects
    GET /region/selects

=cut

sub selects {
    my $self = shift;

    my $orders = $self->DB->resultset('Order')->search( { status_id => $STATUS_SELECT },
        { order_by => { -asc => 'update_date' }, join => 'booking' } )
        ->search_literal( 'HOUR(`booking`.`date`) != ?', 22 );

    my $key   = 'suggestion';
    my $brain = $self->app->brain;
    my $dirq  = Directory::Queue->new( path => "/tmp/opencloset" );

    my %suggestion;
    while ( my $order = $orders->next ) {
        my $user_id    = $order->user_id;
        my $suggestion = $brain->{data}{$key}{$user_id};
        unless ($suggestion) {
            $dirq->add($user_id);
            next;
        }

        $suggestion{$user_id} = $suggestion;
    }

    $orders->reset;

    my @select_active = keys %{ $brain->{data}{select} ||= {} };
    $brain->{data}{select} = {} unless $orders->count;

    $self->render(
        orders        => $orders,
        select_active => [@select_active],
        suggestion    => \%suggestion
    );
}

=head2 rooms

    # region.rooms
    GET /region/rooms

=cut

sub rooms {
    my $self = shift;

    my $brain = $self->app->brain;
    my ( @room_active, @room );

    for my $n ( 1 .. 11 ) {
        my $room;
        my $order = $self->DB->resultset('Order')
            ->search( { status_id => $STATUS_FITTING_ROOM1 + $n - 1 } )->next;
        $room_active[$n] = $brain->{data}{room}{ $order->id } if $order;
        $room[$n] = $order;
    }

    $brain->{data}{room} = {} unless @room_active;

    $self->render(
        rooms       => [@room],
        room_active => [@room_active],
        refresh_active => $brain->{data}{refresh} || {},
    );
}

=head2 repair

    GET /region/status/repair

=cut

sub status_repair {
    my $self = shift;

    my $brain = $self->app->brain;

    my @repair = $self->DB->resultset('Order')->search( { status_id => $STATUS_REPAIR },
        { order_by => { -asc => 'update_date' } } );

    $brain->{data}{repair} = {} unless @repair;

    my %done;
    map { $done{$_} = $brain->{data}{repair}{$_} } keys %{ $brain->{data}{repair} };

    $self->render( repair => [@repair], done => {%done} );
}

=head2 boxed

    GET /region/status/boxing

=cut

sub status_boxing {
    my $self = shift;

    my $brain = $self->app->brain;

    my @boxing = $self->DB->resultset('Order')->search_literal(
        'status_id = ? AND HOUR(booking.date) != ?',
        ( $STATUS_BOXING, 22 ),
        { join => 'booking', order_by => { -asc => 'update_date' } }
    );

    $self->render( boxing => [@boxing] );
}

1;
