package OpenCloset::Monitor;
use Mojo::Base 'Mojolicious';

use Net::IP::AddrRanges;

use OpenCloset::Schema;

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

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('haml_renderer');
    $self->plugin('validator');
    $self->secrets( [time] );
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_whitelist;
    $self->_public_routes;
    $self->_private_routes;
}

sub _assets {
    my $self = shift;

    $self->plugin('AssetPack');
    $self->defaults( { jses => [], csses => [] } );

    $self->asset( 'statistics.css' => '/assets/css/screen.css' );
    $self->asset(
        'screen.css' => qw{
            /assets/css/cover.css
            /assets/css/screen.css
            }
    );
    $self->asset(
        'elapsed.css' => qw{
            /assets/components/nvd3/nv.d3.min.css
            /assets/components/bootstrap-datepicker/css/datepicker3.css
            }
    );
    $self->asset(
        'bundle.js' => qw{
            /assets/components/jquery/dist/jquery.js
            /assets/components/bootstrap/dist/js/bootstrap.js
            /assets/components/underscore/underscore.js
            }
    );
    $self->asset(
        'index.js' => qw{
            /assets/components/reconnectingWebsocket/reconnecting-websocket.js
            /assets/components/backbone/backbone.js
            /assets/js/index.js
            }
    );
    $self->asset(
        'elapsed.js' => qw{
            /assets/components/d3/d3.min.js
            /assets/components/nvd3/nv.d3.min.js
            /assets/components/bootstrap-datepicker/js/bootstrap-datepicker.js
            /assets/components/bootstrap-datepicker/js/locales/bootstrap-datepicker.kr.js
            /assets/components/json2/json2.js
            /assets/js/statistics-elapsed.js
            }
    );
    $self->asset(
        'room.js' => qw{
            /assets/components/jquery-timeago/jquery.timeago.js
            /assets/components/jquery-timeago/locales/jquery.timeago.ko.js
            /assets/components/reconnectingWebsocket/reconnecting-websocket.js
            /assets/js/room.js
            }
    );
    $self->asset(
        'select.js' => qw{
            /assets/components/jquery-timeago/jquery.timeago.js
            /assets/components/jquery-timeago/locales/jquery.timeago.ko.js
            /assets/components/reconnectingWebsocket/reconnecting-websocket.js
            /assets/js/select.js
            }
    );
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

    $r->post('/events')->to('event#create');

    $r->websocket('/socket')->to('socket#socket')->name('socket');
}

1;
