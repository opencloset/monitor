package OpenCloset::Monitor;
use Mojo::Base 'Mojolicious';

use Net::IP::AddrRanges;

use OpenCloset::Schema;
use OpenCloset::Monitor::Schema;

use version; our $VERSION = qv("v0.5.0");

has ranges => sub { Net::IP::AddrRanges->new };
has DB => sub {
    my $self = shift;
    OpenCloset::Schema->connect(
        {
            dsn      => $self->config->{database}{dsn},
            user     => $self->config->{database}{user},
            password => $self->config->{database}{pass},
            %{ $self->config->{database}{opts} },
        }
    );
};
has redis_channel => 'opencloset:monitor';
has SQLite        => sub {
    my $self = shift;
    OpenCloset::Monitor::Schema->connect(
        {
            dsn            => $self->config->{database}{sqlite},
            quote_char     => q{`},
            sqlite_unicode => 1,
        }
    );
};

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('haml_renderer');
    $self->plugin('validator');
    $self->plugin('RemoteAddr');
    $self->secrets( [time] );
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_whitelist;
    $self->_public_routes;
    $self->_private_routes;
}

sub _assets {
    my $self = shift;

    $self->defaults( { jses => [], csses => [] } );
}

sub _whitelist {
    my $self = shift;

    $self->ranges->add( @{ $self->config->{whitelist} ||= [] } );
}

sub _public_routes { }

sub _private_routes {
    my $self = shift;
    my $r    = $self->routes->under('/')->to('user#auth');
    $r->get('/')->to('dashboard#index')->name('index');
    $r->get('/statistics/elapsed')->to('statistics#elapsed')->name('elapsed');
    $r->get('/statistics/elapsed/:ymd')->to('statistics#elapsed_ymd');

    $r->get('/room')->to('dashboard#room')->name('rooms');
    $r->post('/room')->to('dashboard#create_room');
    $r->delete('/room/:order_id')->to('dashboard#delete_room');

    $r->get('/select')->to('dashboard#select')->name('select');
    $r->post('/select')->to('dashboard#create_select');
    $r->delete('/select/:order_id')->to('dashboard#delete_select');

    $r->get('/preparation')->to('dashboard#preparation')->name('preparation');

    $r->post('/events')->to('event#create');

    $r->websocket('/socket')->to('socket#socket')->name('socket');

    $r->put('/api/orders/:order_id')->to('API#order');

    $r->get('/repair')->to('dashboard#repair')->name('repair');
    $r->get('/online')->to('dashboard#online')->name('online');
    $r->get('/address')->to('API#address')->name('address');
    $r->post('/sms')->to('API#create_sms')->name('sms.create');
}

1;
