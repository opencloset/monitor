#!/usr/bin/env perl
use Mojolicious::Lite;

use Directory::Queue;
use JSON;
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

our @ACTIVE_STATUS = (
    $STATUS_REPAIR, $STATUS_VISIT, $STATUS_MEASURE, $STATUS_SELECT,
    $STATUS_BOXING, $STATUS_PAYMENT,
    $STATUS_FITTING_ROOM1 .. $STATUS_FITTING_ROOM9
);
our @NOTIFICATION_STATUS = @ACTIVE_STATUS;

my $DIRQ = Directory::Queue->new( path => "/tmp/opencloset/monitor" );
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => app->config->{database}{dsn},
        user     => app->config->{database}{user},
        password => app->config->{database}{pass},
        %{ app->config->{database}{opts} },
    }
);

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
            my @events;
            for ( my $name = $DIRQ->first(); $name; $name = $DIRQ->next() ) {
                next unless $DIRQ->lock($name);
                my $data = decode_json( $DIRQ->get($name) );
                push @events,
                    {
                    order => $DB->resultset('Order')
                        ->find( { id => $data->{order_id} } ),
                    status => { from => $data->{from}, to => $data->{to} }
                    };
                $DIRQ->remove($name);
            }

            $self->stash(
                orders => [
                    [@visit], [@measure], [@select], [@undress],
                    [@repair], [@boxing], [@payment]
                ],
                events   => [@events],
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
    if ( grep { $to == $_ } @NOTIFICATION_STATUS ) {
        $DIRQ->add(
            encode_json(
                {
                    order_id => $self->param('order_id'),
                    from     => $self->param('from'),
                    to       => $self->param('to')
                }
            )
        );
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

app->sessions->cookie_name('opencloset-monitor');
app->secrets( [time] );
app->start;
