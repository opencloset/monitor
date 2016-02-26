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

    # brain 의 데이터 변경
    $validator->when('sender')->regexp(qw/brain/)->then(
        sub {
            shift->field( [qw/ns key/] )    # namespace
                ->each( sub { shift->required(1) } );
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

        ###
        ### 정리가 필요한 탈의실 표시
        ###
        ### `의류준비|탈의` -> `대여안함|포장|수선` 으로 이동했을때에 탈의실의 정리가 필요해서
        ### 이를 강조해주기 위한 데이터 추가
        my $brain = $self->app->brain;
        if (   $to == $OpenCloset::Status::STATUS_DO_NOT_RENTAL
            || $to == $OpenCloset::Status::STATUS_BOXING
            || $to == $OpenCloset::Status::STATUS_REPAIR )
        {
            if ( $from == $OpenCloset::Status::STATUS_SELECT ) {
                my $history
                    = $self->app->SQLite->resultset('History')
                    ->search( { order_id => $order->id },
                    { rows => 1, order_by => { -desc => 'id' } } )->next;

                $brain->{data}{refresh}{ $history->room_no } = 1 if $history;
            }
            elsif ($from >= $OpenCloset::Status::STATUS_FITTING_ROOM1
                && $from <= $OpenCloset::Status::STATUS_FITTING_ROOM11 )
            {
                $brain->{data}{refresh}{ $from - 19 } = 1;
            }
        }

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
    elsif ( $sender eq 'brain' ) {
        my $ns  = $self->param('ns');
        my $key = $self->param('key');

        my $brain = $self->app->brain;
        if ( $self->app->brain->{data}{$ns}{$key} ) {
            delete $brain->{data}{$ns}{$key};
        }
        else {
            $brain->{data}{$ns}{$key} = 1;
        }

        $self->redis->publish(
            "$channel:brain" => decode_utf8(
                j( { sender => $sender, brain => $brain->{data}{$ns} } )
            )
        );
    }
    else {
        $self->app->log->warn("Unknown sender: $sender");
    }

    $self->render( text => 'Successfully posted event', status => 201 );
}

1;
