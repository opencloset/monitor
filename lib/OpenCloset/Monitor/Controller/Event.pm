package OpenCloset::Monitor::Controller::Event;
use Mojo::Base 'Mojolicious::Controller';

use Encode 'decode_utf8';
use Mojo::JSON 'j';

has DB => sub { shift->app->DB };

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

        $self->redis->publish(
            "$channel:order" => decode_utf8(
                j(
                    {
                        sender => $sender,
                        order  => $self->order_flatten($order),
                        from   => $self->param('from'),
                        to     => $self->param('to')
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
