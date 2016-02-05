package OpenCloset::Monitor::Plugin::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

use DateTime;
use Mojo::Redis2;

use OpenCloset::Brain;

sub register {
    my ( $self, $app, $conf ) = @_;
    $app->helper( log => sub { shift->app->log } );
    $app->helper( error          => \&error );
    $app->helper( age            => \&age );
    $app->helper( order_flatten  => \&order_flatten );
    $app->helper( user_flatten   => \&user_flatten );
    $app->helper( redis          => \&redis );
    $app->helper( previous_order => \&previous_order );
    $app->helper( history        => \&history );
    $app->helper( recent_orders  => \&recent_orders );
    $app->helper( target_date    => \&target_date );
}

sub order_flatten {
    my ( $self, $order ) = @_;
    my $user      = $order->user;
    my $booking   = $order->booking;
    my $user_info = $user->user_info;
    my %columns   = $order->get_columns;
    $columns{user}      = { $user->get_columns };
    $columns{user_info} = { $user_info->get_columns };
    $columns{booking}   = { $booking->get_columns };
    delete $columns{user}{password};
    delete $columns{user_info}{password};
    return {%columns};
}

sub user_flatten {
    my ( $self, $user ) = @_;
    my $user_info = $user->user_info;
    my %columns   = $user->get_columns;
    $columns{user_info} = { $user_info->get_columns };
    delete $columns{user}{password};
    delete $columns{user_info}{password};
    return {%columns};
}

sub error {
    my ( $self, $status, $error ) = @_;

    $self->app->log->error( $error->{str} );

    no warnings 'experimental';
    my $template;
    given ($status) {
        $template = 'bad_request' when 400;
        $template = 'not_found' when 404;
        $template = 'exception' when 500;
        default { $template = 'unknown' }
    }

    $self->respond_to(
        json => { status => $status, json => { error => $error || q{} } },
        html => {
            status => $status,
            error => $error->{str} || q{},
            template => $template
        },
    );

    return;
}

sub age {
    my ( $self, $birth ) = @_;
    my $now = DateTime->now;
    return $now->year - $birth;
}

sub redis {
    my $self = shift;

    $self->stash->{redis} ||= do {
        my $log   = $self->app->log;
        my $redis = Mojo::Redis2->new;    # just use `redis://localhost:6379`
        $redis->on(
            error => sub {
                $log->error("[REDIS ERROR] $_[1]");
            }
        );

        $redis;
    };
}

sub previous_order {
    my ( $self, $room_no ) = @_;
    return unless $room_no;

    my $rs
        = $self->app->SQLite->resultset('History')
        ->search( { room_no => $room_no },
        { rows => 2, order_by => { -desc => 'id' } } );

    $rs->next;    # ignore myself
    my $history = $rs->next;

    return unless $history;
    return $self->app->DB->resultset('Order')
        ->find( { id => $history->order_id } );
}

sub history {
    my ( $self, $cond, $attr ) = @_;

    $attr = { order_by => { -desc => 'id' } } unless $attr;
    return $self->app->SQLite->resultset('History')->search( $cond, $attr );
}

sub recent_orders {
    my ( $self, $order, $limit ) = @_;
    return unless $order;

    my $rs = $order->user->search_related(
        'orders',
        { -not     => { id    => $order->id } },
        { order_by => { -desc => 'id' } }
    );

    $limit = 5 unless $limit;
    return $rs->slice( 0, $limit - 1 );
}

sub target_date {
    my $self = shift;

    my $brain = OpenCloset::Brain->new;
    my $target_date = DateTime->now->add( days => 3 );
    $target_date->set_time_zone('Asia/Seoul');
    if ( my $ymd = $brain->{data}{expiration} ) {
        my $dt = DateTime::Format::ISO8601->parse_datetime($ymd);
        $dt->set_time_zone('Asia/Seoul');
        $target_date = $dt if DateTime->compare( $target_date, $dt ) == -1;
    }

    return $target_date;
}

1;

=pod

=encoding utf8

=head1 NAME

OpenCloset::Plugin::Helpers - provide helpers for opencloset

=head1 SYNOPSIS

    # Mojolicious::Lite
    plugin 'OpenCloset::Plugin::Helpers';

=head1 HELPERS

=head2 error

    get '/foo' => sub {
        my $self = shift;
        my $required = $self->param('something');
        return $self->error(400, 'oops wat the..') unless $required;
    } => 'foo';

=head2 recent_orders

Arguments: $order, $limit?
Return: $resultset (scalar context) | @result_objs (list context)

    my $orders = $c->recent_order($order);

사용자의 C<$order> 를 제외한 최근 주문서를 찾습니다.
C<$limit> 의 기본값은 C<5> 입니다.

=head2 target_date

return target_date

=cut
