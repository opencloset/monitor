package OpenCloset::Monitor::Controller::Event;
use Mojo::Base 'Mojolicious::Controller';

use Encode 'decode_utf8';
use Mojo::JSON 'j';

use OpenCloset::Status;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 create

    POST /events

=cut

sub create {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field('sender')->required(1);

    # 주문서가 변경
    $validator->when('sender')->regexp(qw/order/)->then(
        sub {
            shift->field( [qw/order_id from to/] )
                ->each( sub { shift->required(1) } );
        }
    );

    # 사용자정보가변경
    $validator->when('sender')->regexp(qw/user/)->then(
        sub {
            shift->field('user_id')->required(1);
        }
    );

    unless ( $self->validate($validator) ) {
        my $errors = $validator->errors;
        my @error;
        map { push @error, "$_ is $errors->{$_}" } keys %$errors;
        my $str = join( ', ', @error );
        return $self->error( 400, { str => $str } );
    }

    my $sender  = $self->param('sender');
    my $channel = $self->app->redis_channel;
    if ( $sender eq 'order' ) {
        my $order = $self->DB->resultset('Order')
            ->find( { id => $self->param('order_id') } );

        my $from = $self->param('from');
        my $to   = $self->param('to');

        if (   $to >= $OpenCloset::Status::STATUS_FITTING_ROOM1
            && $to <= $OpenCloset::Status::STATUS_FITTING_ROOM11 )
        {
            $self->app->SQLite->resultset('History')
                ->create( { room_no => $to - 19, order_id => $order->id } );
        }

        # history
        my $histories = $self->history( { order_id => $order->id } );
        my $extra = { nth => $histories ? $histories->count : 0 };

        $self->redis->publish(
            "$channel:order" => decode_utf8(
                j(
                    {
                        sender => $sender,
                        order  => $self->order_flatten($order),
                        from   => $from,
                        to     => $to,
                        extra  => $extra
                    }
                )
            )
        );
    }
    elsif ( $sender eq 'user' ) {
        my $user = $self->DB->resultset('User')
            ->find( { id => $self->param('user_id') } );
        $self->redis->publish(
            "$channel:user" => decode_utf8(
                j( { sender => $sender, user => $self->user_flatten($user) } )
            )
        );
    }
    else {
        $self->app->log->warn("Unknown sender: $sender");
    }

    $self->render( text => 'Successfully posted event', status => 201 );
}

1;
