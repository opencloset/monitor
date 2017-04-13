package OpenCloset::Monitor::Controller::Reservation;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use DateTime::Format::ISO8601;
use Try::Tiny;

use OpenCloset::Constants::Status qw/$RESERVATED $RETURNED/;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /reservation

=cut

sub index {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $tz = $self->config->{timezone};
    my $today = DateTime->today( time_zone => $tz );
    $self->redirect_to( '/reservation/' . $today->ymd );
}

=head2 ymd

    GET /reservation/:ymd

=cut

sub ymd {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $date = try {
        DateTime::Format::ISO8601->parse_datetime($ymd);
    }
    catch {
        $self->log->error("Failed to parse_datetime($ymd): $_");
        return;
    };

    return $self->error( 400, { str => "Invalid ymd(yyyy-mm-dd) format: $ymd" } )
        unless $date;
}

=head2 search

    GET /reservation/:ymd/search?q=xxx

=cut

sub search {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $v = $self->validation;
    $v->input( { ymd => $ymd } );
    $v->required('ymd')->like(qr/^\d{4}-\d{2}-\d{2}$/);

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my $error = 'Parameter Validation Failed: ' . join( ', ', @$failed );
        return $self->error( 400, { str => $error } );
    }

    my $q = $self->param('q');
    return $self->error( 400, { str => 'Parameter "q" is required' } ) unless $q;
    return $self->error( 400, { str => 'Query is too short' } ) if length $q < 2;

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
        push @or, { name => { like => "%$q%" } };
    }

    my ( $yyyy, $mm, $dd ) = $ymd =~ m/^(\d{4})-(\d{2})-(\d{2})$/;
    my $timezone = $self->config->{timezone};
    my $dt_start = DateTime->new( year => $yyyy, month => $mm, day => $dd,
        time_zone => $timezone );
    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );

    my $dtf = $self->DB->storage->datetime_parser;
    my $rs  = $self->DB->resultset('Order')->search(
        {
            -or  => [@or],
            -and => [
                status_id      => $RESERVATED,
                'booking.date' => {
                    -between => [
                        $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end)
                    ],
                },
                online => 0,
            ]
        },
        {
            join => ['booking', { user => 'user_info' }],
            rows => 10,
            order_by => { -asc => 'booking.date' },
        }
    );

    my @orders;
    while ( my $order = $rs->next ) {
        my $user        = $order->user;
        my $user_info   = $user->user_info;
        my $coupon      = $order->coupon;
        my $coupon_desc = $coupon ? $coupon->desc : '';
        my $event_seoul = $coupon_desc =~ m/^seoul/;

        #
        # GH 1142: 대여 화면에서 예약자의 이전 방문 기록 확인
        #
        my $visited = 0;
        my $ago     = 0;
        {
            my $visited_order_rs = $user->orders(
                { status_id => $RETURNED, parent_id => undef, },
                { order_by => { -desc => 'return_date' } },
            );

            $visited = $visited_order_rs->count;
            my $last_order = $visited_order_rs->first;
            if ($last_order) {
                my $booking            = $order->booking;
                my $last_order_booking = $last_order->booking;
                if ( $booking && $last_order_booking ) {
                    my $dur = $booking->date->delta_days( $last_order_booking->date );
                    $ago = $dur->delta_days;
                }
            }
        }

        push @orders,
            {
            ago          => $ago,
            booking      => substr( $order->booking->date, 11, 5 ),
            email        => $user->email,
            event_seoul  => $event_seoul,
            foot         => $user_info->foot,
            name         => $user->name,
            order_id     => $order->id,
            phone        => $user_info->phone,
            pre_category => $user_info->pre_category,
            user_id      => $user->id,
            visited      => $visited,
            return_memo  => $order->return_memo,
            };
    }

    $self->render( json => \@orders );
}

1;
