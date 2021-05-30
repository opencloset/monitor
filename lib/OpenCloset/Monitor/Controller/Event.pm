package OpenCloset::Monitor::Controller::Event;
use Mojo::Base 'Mojolicious::Controller';

use Encode 'decode_utf8';
use Mojo::JSON 'j';
use Try::Tiny;

use OpenCloset::Constants qw/$MONITOR_TTS_TO_INDEX $MONITOR_TTS_TO_ROOM/;
use OpenCloset::Monitor::Status;

our $PREFIX = 'opencloset:storage';

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
            shift->field( [qw/order_id from to/] )->each( sub { shift->required(1) } );
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
        my $order
            = $self->DB->resultset('Order')->find( { id => $self->param('order_id') } );

        my $from = $self->param('from');
        my $to   = $self->param('to');

        if (   $to >= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1
            && $to <= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM15 )
        {
            my $room_no = $to - 19;
            $self->app->SQLite->resultset('History')
                ->create( { room_no => $room_no, order_id => $order->id } );

            my $count = $self->app->SQLite->resultset('History')
                ->search( { order_id => $order->id } )->count;

            if ( $count == 1 ) {
                my $user = $order->user;
                my $name = $user->name . '님';
                ## GH #195
                ## 또박또박 읽기 위해서 이름 사이에 `.` 을 넣는데, 영문은 자연스럽게 둔다.
                $name = join( '.', split //, $name ) if $user->name !~ m/^[a-zA-Z0-9 ]+$/;
                try {
                    $self->minion->enqueue(tts => [
                        $name,
                        $MONITOR_TTS_TO_INDEX,
                        $room_no
                    ]);
                } catch {
                    $self->log->error("Failed enqueue TTS task to Minion");
                };

                ## GH #181
                ## 치수측정 -> 탈의가 첫번째라면 history 캐시만 저장하고 상태를 의류준비로 변경한다.
                $to = $OpenCloset::Monitor::Status::STATUS_SELECT;
                $order->update( { status_id => $to } );
            } elsif ( $count == 2 ) {
                ## GH #181
                ## > 2> 000님, n번 탈의실에 의류가 준비되었습니다 멘트가 최초 한번만 나오게 요청드립니다.
                ## > 교환으로 인해 다시 넣을 때마다 안내멘트가 나올 필요는 없다는 의견입니다.

                ## 옷장지기가 의류준비 -> 탈의n 으로 변경했을때가 count: 2
                my $user = $order->user;
                my $name = $user->name . '님';
                $name = join( '.', split //, $name );
                try {
                    $self->minion->enqueue(tts => [
                        $name,
                        $MONITOR_TTS_TO_ROOM,
                        $room_no
                    ]);
                } catch {
                    $self->log->error("Failed enqueue TTS task to Minion");
                };
            }
        }

        # history
        my $histories = $self->history( { order_id => $order->id } );
        my $extra = { nth => $histories ? $histories->count : 0 };

        ###
        ### 정리가 필요한 탈의실 표시
        ###
        ### `의류준비|탈의` -> `대여안함|포장|수선` 으로 이동했을때에 탈의실의 정리가 필요해서
        ### 이를 강조해주기 위한 데이터 추가
        my $redis = $self->redis;
        if (   $to == $OpenCloset::Monitor::Status::STATUS_DO_NOT_RENTAL
            || $to == $OpenCloset::Monitor::Status::STATUS_BOXING
            || $to == $OpenCloset::Monitor::Status::STATUS_REPAIR )
        {
            if ( $from == $OpenCloset::Monitor::Status::STATUS_SELECT ) {
                my $history
                    = $self->app->SQLite->resultset('History')
                    ->search( { order_id => $order->id },
                    { rows => 1, order_by => { -desc => 'id' } } )->next;
                $redis->hset( "$PREFIX:refresh", $history->room_no, 1 ) if $history;
            }
            elsif ($from >= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1
                && $from <= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM15 )
            {
                $redis->hset( "$PREFIX:refresh", $from - 19, 1 );
            }
        }

        $redis->publish(
            "$channel:order" => decode_utf8(
                j(
                    {
                        sender => $sender,
                        order  => $self->order_flatten($order),
                        from   => int($from),
                        to     => int($to),
                        extra  => $extra
                    }
                )
            )
        );
    }
    elsif ( $sender eq 'user' ) {
        my $user
            = $self->DB->resultset('User')->find( { id => $self->param('user_id') } );
        $self->redis->publish(
            "$channel:user" => decode_utf8(
                j( { sender => $sender, user => $self->user_flatten($user) } )
            )
        );
    }
    elsif ( $sender eq 'brain' ) {
        my $ns  = $self->param('ns');
        my $key = $self->param('key');

        my $redis = $self->redis;
        if ( $redis->hget( "$PREFIX:$ns", $key ) ) {
            $redis->hdel( "$PREFIX:$ns", $key );
        }
        else {
            $redis->hset( "$PREFIX:$ns", $key, 1 );
        }

        $self->redis->publish(
            "$channel:brain" => decode_utf8(
                j(
                    {
                        sender => $sender,
                        brain  => { @{ $redis->hgetall("$PREFIX:$ns") } }
                    }
                )
            )
        );
    }
    else {
        $self->log->warn("Unknown sender: $sender");
    }

    $self->render( text => 'Successfully posted event', status => 201 );
}

1;
