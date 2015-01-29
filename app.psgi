#!/usr/bin/env perl
use Mojolicious::Lite;

use Encode 'decode_utf8';
use JSON;
use Mojo::JSON 'j';
use Net::IP::AddrRanges;
use Path::Tiny;
use Time::HiRes 'time';
use feature qw/switch/;

use OpenCloset::Brain;
use OpenCloset::Schema;
use OpenCloset::Status;

app->defaults(
    %{ plugin 'Config' =>
            { default => { jses => [], csses => [], page_id => q{} } }
    }
);

my $DB = OpenCloset::Schema->connect(
    {
        dsn      => app->config->{database}{dsn},
        user     => app->config->{database}{user},
        password => app->config->{database}{pass},
        %{ app->config->{database}{opts} },
    }
);

my $REDIS_CHANNEL = 'opencloset:monitor';

plugin 'OpenCloset::Plugin::Helpers';
plugin 'haml_renderer';
plugin 'validator';

my $ranges = Net::IP::AddrRanges->new();
$ranges->add( @{ app->config->{whitelist} } );

under sub {
    my $self    = shift;
    my $address = $self->tx->remote_address;
    my $method  = $self->tx->req->method;
    return 1 if $method ne 'GET';
    unless ( $ranges->find($address) ) {
        app->log->warn("denied address: $address");
        $self->render( text => 'Permission denied' );
        return;
    }
    return 1;
};

get '/' => sub {
    my $self = shift;
    my $rs
        = $DB->resultset('Order')
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
                ],
                template => 'index'
            );
        }
    );
};

get '/statistics';
get '/statistics/elapsed'      => 'statistics/elapsed';
get '/statistics/elapsed/:ymd' => sub {
    my $self = shift;
    my $ymd  = $self->param('ymd');
    my ( $year, $month ) = split /-/, $ymd;
    my $tsv = path("statistics/elapsed/$year/$month/$ymd.tsv");
    return $self->error( 404, { str => "Not found data: $tsv" } )
        unless $tsv->exists;

    my %gdata;
    for my $line ( $tsv->lines( { chomp => 1 } ) ) {
        my ( $gender, $status_id, $value ) = split /\t/, $line;
        push @{ $gdata{daily}{$gender} ||= [] },
            { label => $OpenCloset::Status::MAP{$status_id}, value => $value };
        $gdata{daily}{sum}{$gender} += $value;
    }

    my %color = ( male => '#4d4dff', female => '#ff4d4d' );
    for my $gender (qw/male female/) {
        my @values;
        for my $data ( sort status_reverse_order @{ $gdata{daily}{$gender} } )
        {
            push @values,
                {
                x => $OpenCloset::Status::REVERSE_ORDER_MAP{ $data->{label} },
                y => $data->{value},
                };
        }
        push @{ $gdata{bars} ||= [] },
            {
            key    => "$ymd-$gender",
            values => [@values],
            color  => $color{$gender}
            };
    }

    my $brain   = OpenCloset::Brain->new;
    my $average = $brain->{data}{statistics}{elapsed_time};

    $color{male}   = '#0000ff';
    $color{female} = '#ff0000';
    for my $gender (qw/male female/) {
        my @values;
        for my $status_id ( sort status_order keys %{ $average->{$gender} } ) {
            push @values,
                {
                x => $OpenCloset::Status::ORDER_MAP{$status_id},
                y => $average->{$gender}{$status_id},
                };
        }
        push @{ $gdata{bars} ||= [] },
            {
            key    => "average-$gender",
            values => [@values],
            color  => $color{$gender}
            };
    }

    $self->respond_to( json => { json => { gdata => {%gdata} } } );
};

sub status_reverse_order {
    $OpenCloset::Status::REVERSE_ORDER_MAP{ $a->{label} }
        <=> $OpenCloset::Status::REVERSE_ORDER_MAP{ $b->{label} };
}

sub status_order {
    $OpenCloset::Status::ORDER_MAP{$a} <=> $OpenCloset::Status::ORDER_MAP{$b};
}

post '/events' => sub {
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

    my $sender = $self->param('sender');
    if ( $sender eq 'order' ) {
        my $order = $DB->resultset('Order')
            ->find( { id => $self->param('order_id') } );

        $self->redis->publish(
            "$REDIS_CHANNEL:order" => decode_utf8(
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
        my $user = $DB->resultset('User')
            ->find( { id => $self->param('user_id') } );
        $self->redis->publish(
            "$REDIS_CHANNEL:user" => decode_utf8(
                j( { sender => $sender, user => $self->user_flatten($user) } )
            )
        );
    }
    else {
        $self->app->log->warn("Unknown sender: $sender");
    }

    $self->render( text => 'Successfully posted event', status => 201 );
};

# fitting room
get '/room' => sub {
    my $self  = shift;
    my $brain = OpenCloset::Brain->new;
    my ( @active, @room );
    for my $n ( 1 .. 11 ) {
        my $room;
        my $order = $DB->resultset('Order')->search(
            {
                status_id => $OpenCloset::Status::STATUS_FITTING_ROOM1 + $n - 1
            }
        )->next;
        $active[$n] = $brain->{data}{orders}{room}{ $order->id } if $order;
        $room[$n] = $order;
    }

    $brain->{data}{orders}{room} = {} unless @active;
    $self->stash( rooms => [@room], active => [@active] );
};

post '/room' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    $brain->{data}{orders}{room}{$order_id} = 1;
    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
};

del '/room/:order_id' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    delete $brain->{data}{orders}{room}{$order_id};
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
};

get '/select' => sub {
    my $self = shift;
    my $rs   = $DB->resultset('Order')->search(
        { status_id => $OpenCloset::Status::STATUS_SELECT },
        { order_by  => { -asc => 'update_date' } }
    );

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{orders} = {} unless $rs->count;
    my @active = keys %{ $brain->{data}{orders}{select} ||= {} };
    $self->stash( orders => $rs, active => [@active] );
};

post '/select' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    $brain->{data}{orders}{select}{$order_id} = 1;
    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
};

del '/select/:order_id' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    delete $brain->{data}{orders}{select}{$order_id};
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
};

websocket '/socket' => sub {
    my $self = shift;

    $self->app->log->debug('WebSocket opened');
    $self->inactivity_timeout(300);
    Scalar::Util::weaken($self);

    my $log = $self->app->log;
    $self->on(
        message => sub {
            my ( $self, $msg ) = @_;
            $log->debug("[ws] < $msg");

            if ( my ($channel) = $msg =~ /^\/subscribe:? +([a-z]+)/i ) {
                $self->redis->subscribe(
                    "$REDIS_CHANNEL:$channel" => sub {
                        my ( $redis, $err ) = @_;
                        $log->error("[REDIS ERROR] subscribe error: $err")
                            if $err;
                    }
                );
            }
        }
    );

    $self->on(
        finish => sub {
            my ( $self, $code, $reason ) = @_;
            $log->debug("WebSocket closed with status $code");
            delete $self->stash->{redis};
        }
    );

    $self->redis->on(
        message => sub {
            my ( $redis, $message, $ch ) = @_;
            return if $ch !~ /$REDIS_CHANNEL/;
            return unless $self;
            $self->send($message);
        }
    );
};

app->sessions->cookie_name('opencloset-monitor');
app->secrets( [time] );
app->start;
