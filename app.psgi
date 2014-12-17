#!/usr/bin/env perl
use Mojolicious::Lite;

use JSON;
use Time::HiRes 'time';
use feature qw/switch/;

use OpenCloset::Schema;
use OpenCloset::Brain;

app->defaults(
    %{ plugin 'Config' =>
            { default => { jses => [], csses => [], page_id => q{} } }
    }
);

our $STATUS_REPAIR  = 6;
our $STATUS_VISIT   = 13;
our $STATUS_MEASURE = 16;
our $STATUS_SELECT  = 17;
our $STATUS_BOXING  = 18;
our $STATUS_PAYMENT = 19;

our $STATUS_FITTING_ROOM1 = 20;
our $STATUS_FITTING_ROOM2 = 21;
our $STATUS_FITTING_ROOM3 = 22;
our $STATUS_FITTING_ROOM4 = 23;
our $STATUS_FITTING_ROOM5 = 24;
our $STATUS_FITTING_ROOM6 = 25;
our $STATUS_FITTING_ROOM7 = 26;
our $STATUS_FITTING_ROOM8 = 27;
our $STATUS_FITTING_ROOM9 = 28;

our %STATUS_MAP = (
    16 => 'measure',
    19 => 'payment',
    20 => 'fitting',
    21 => 'fitting',
    22 => 'fitting',
    23 => 'fitting',
    24 => 'fitting',
    25 => 'fitting',
    26 => 'fitting',
    27 => 'fitting',
    28 => 'fitting',
    29 => 'fitting'
);

our @ACTIVE_STATUS = (
    $STATUS_REPAIR, $STATUS_VISIT, $STATUS_MEASURE, $STATUS_SELECT,
    $STATUS_BOXING, $STATUS_PAYMENT,
    $STATUS_FITTING_ROOM1 .. $STATUS_FITTING_ROOM9
);

my $DB = OpenCloset::Schema->connect(
    {
        dsn      => app->config->{database}{dsn},
        user     => app->config->{database}{user},
        password => app->config->{database}{pass},
        %{ app->config->{database}{opts} },
    }
);

my %sock_clients;

plugin 'OpenCloset::Plugin::Helpers';
plugin 'haml_renderer';
plugin 'validator';

under sub {
    my $self    = shift;
    my $address = $self->tx->remote_address;
    my $method  = $self->tx->req->method;
    return 1 if $method ne 'GET';
    unless ( grep { $address eq $_ } @{ $self->config->{whitelist} } ) {
        $self->render( text => 'Permission denied' );
        return;
    }
    return 1;
};

get '/' => sub {
    my $self = shift;
    my $rs   = $DB->resultset('Order')->search(
        { status_id => { -in  => [@ACTIVE_STATUS] } },
        { order_by  => { -asc => 'update_date' } }
    );

    my ( @visit, @measure, @select, @undress, @repair, @boxing, @payment );
    while ( my $order = $rs->next ) {
        my $status_id = $order->status_id;
        use experimental qw/ smartmatch /;
        given ($status_id) {
            when ($STATUS_VISIT)   { push @visit,   $order }
            when ($STATUS_MEASURE) { push @measure, $order }
            when ($STATUS_SELECT)  { push @select,  $order }
            when ( [$STATUS_FITTING_ROOM1 .. $STATUS_FITTING_ROOM9] ) {
                push @undress, $order
            }
            when ($STATUS_REPAIR)  { push @repair,  $order }
            when ($STATUS_BOXING)  { push @boxing,  $order }
            when ($STATUS_PAYMENT) { push @payment, $order }
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

post '/events' => sub {
    my $self = shift;

    my $validator = $self->create_validator;
    $validator->field( [qw/order_id from to/] )
        ->each( sub { shift->required(1) } );
    return $self->error( 400,
        { str => 'parameter `order_id`, `from` and `to` are required' } )
        unless $self->validate($validator);

    my $to = $self->param('to');

    my $order
        = $DB->resultset('Order')->find( { id => $self->param('order_id') } );
    my $template = $STATUS_MAP{ $order->status_id };
    for my $key ( keys %sock_clients ) {
        $sock_clients{$key}->send('') unless $template;
        my $html = $self->render_to_string(
            "partials/event/$template",
            order => $order,
            from  => $self->param('from'),
            to    => $self->param('to')
        )->to_string;
        $sock_clients{$key}->send($html);
    }

    $self->render( text => 'Successfully posted event', status => 201 );
};

# fitting room
get '/room' => sub {
    my $self = shift;
    for my $n ( 1 .. 9 ) {
        $self->stash( "room$n" => $DB->resultset('Order')
                ->search( { status_id => $STATUS_FITTING_ROOM1 + $n - 1 } )
                ->next );
    }
};

get '/select' => sub {
    my $self = shift;
    my $rs = $DB->resultset('Order')->search( { status_id => $STATUS_SELECT },
        { order_by => { -asc => 'update_date' } } );

    my $brain = OpenCloset::Brain->new;
    $brain->{data}{orders} = {} unless $rs->count;
    my @active = keys %{ $brain->{data}{orders} ||= {} };
    $self->stash( orders => $rs, active => [@active] );
};

post '/select' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    $brain->{data}{orders}{$order_id} = 1;
    $self->render(
        text   => "Successfully posted order_id($order_id)",
        status => 201
    );
};

del '/select/:order_id' => sub {
    my $self     = shift;
    my $order_id = $self->param('order_id');
    my $brain    = OpenCloset::Brain->new;
    delete $brain->{data}{orders}{$order_id};
    $self->render(
        text   => "Successfully deleted order_id($order_id)",
        status => 201
    );
};

websocket '/socket' => sub {
    my $self = shift;
    $self->app->log->debug('WebSocket opened');
    $self->inactivity_timeout(300);
    my $tx = $self->tx;
    my $t0 = time;
    $sock_clients{$t0} = $tx;
    $self->on(
        message => sub {
            my ( $self, $msg ) = @_;
            $self->app->log->debug("[ws] < $msg");
        }
    );

    $self->on(
        finish => sub {
            my ( $self, $code, $reason ) = @_;
            $self->app->log->debug("WebSocket closed with status $code");
            delete $sock_clients{$t0};
        }
    );
};

app->sessions->cookie_name('opencloset-monitor');
app->secrets( [time] );
app->start;
