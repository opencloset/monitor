#!/usr/bin/env perl
use Mojolicious::Lite;
use OpenCloset::Schema;

app->defaults(
    %{ plugin 'Config' =>
            { default => { jses => [], csses => [], page_id => q{} } }
    }
);

our @ACTIVE_STATUS = qw/3 13 16 17 18 19 20/;
my $DB = OpenCloset::Schema->connect(
    {
        dsn      => app->config->{database}{dsn},
        user     => app->config->{database}{user},
        password => app->config->{database}{pass},
        %{ app->config->{database}{opts} },
    }
);

plugin 'haml_renderer';

helper order_flatten => sub {
    my ( $self, $order ) = @_;
    return { $order->get_columns };
};

get '/' => sub {
    my $c = shift;
    $c->render('index');
};

get '/dashboard' => sub {
    my $self = shift;
    my $rs   = $DB->resultset('Order')
        ->search( { status_id => { -in => [@ACTIVE_STATUS] } } );
    $self->respond_to(
        json => sub {
            my @orders;
            while ( my $order = $rs->next ) {
                push @orders, $self->order_flatten($order);
            }
            return [@orders];
        },
        html => sub {
            $self->stash( orders => $rs, template => 'dashboard' );
        }
    );
};

app->start;
