#!/usr/bin/env perl
use Mojolicious::Lite;
use Directory::Queue;
use JSON;

use OpenCloset::Schema;

app->defaults(
    %{ plugin 'Config' =>
            { default => { jses => [], csses => [], page_id => q{} } }
    }
);

our @ACTIVE_STATUS       = qw/6 13 16 17 18 19 20/;
our @NOTIFICATION_STATUS = qw/16 18 20/;
my $DIRQ = Directory::Queue->new( path => "/tmp/opencloset/monitor" );
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => app->config->{database}{dsn},
        user     => app->config->{database}{user},
        password => app->config->{database}{pass},
        %{ app->config->{database}{opts} },
    }
);

plugin 'haml_renderer';
plugin 'opencloset';
plugin 'validator';

helper order_flatten => sub {
    my ( $self, $order ) = @_;
    return { $order->get_columns };
};

get '/' => sub {
    my $self = shift;
    my $rs   = $DB->resultset('Order')->search(
        { status_id => { -in  => [@ACTIVE_STATUS] } },
        { order_by  => { -asc => 'update_date' } }
    );

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
                orders   => $rs,
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

app->sessions->cookie_name('opencloset-monitor');
app->secrets( app->defaults->{secrets} );
app->start;
