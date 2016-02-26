package OpenCloset::Monitor;
use Mojo::Base 'Mojolicious';

use Net::IP::AddrRanges;

use OpenCloset::Monitor::Schema;
use OpenCloset::Schema;
use OpenCloset::Status;

use version; our $VERSION = qv("v0.6.2");

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
    $self->plugin('OpenCloset::Monitor::Plugin::Helpers');
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
    $r->get('/select')->to('dashboard#select')->name('select');

    $r->post('/active')->to('dashboard#create_active');
    $r->delete('/active/:order_id')->to('dashboard#delete_active');

    $r->get('/preparation')->to('dashboard#preparation')->name('preparation');

    $r->post('/events')->to('event#create');

    $r->websocket('/socket')->to('socket#socket')->name('socket');

    $r->put('/api/orders/:order_id')->to('API#order');

    $r->get('/repair')->to('dashboard#repair')->name('repair');
    $r->get('/online')->to('dashboard#online')->name('online');
    $r->get('/address')->to('API#address')->name('address');
    $r->post('/sms')->to('API#create_sms')->name('sms.create');
    $r->put('/brain')->to('API#update_brain')->name('brain.update');
    $r->get('/target_date')->to('API#target_dt')->name('api.target_date');
    $r->options('/target_date')->to('API#cors');
}

=head2 _waiting_list

성별/상태별 대기인원의 수를 돌려줌

    my $waiting_list = $self->app->_waiting_list;
    print $waiting_list->{male}{18};      # 포장 상태인 남성의 수
    print $waiting_list->{female}{18};    # 포장 상태인 여성의 수

=cut

sub _waiting_list {
    my $self = shift;

    ## 각 상태별 주문서의 갯수 를 남녀별로
    ## 22:00 주문서는 온라인 주문서이기 때문에 제외
    my $rs = $self->DB->resultset('Order')->search(
        { status_id => { -in => [@OpenCloset::Status::ACTIVE_STATUS] }, },
        {
            select =>
                ['status_id', 'user_info.gender', { count => 'status_id' }],
            as       => [qw/status_id gender cnt/],
            group_by => ['status_id', 'user_info.gender'],
            join     => ['booking', { user => 'user_info' }]
        }
    )->search_literal('HOUR(`booking`.`date`) != 22');

    my %waiting;
    while ( my $row = $rs->next ) {
        my $status_id = $row->get_column('status_id');
        my $gender    = $row->get_column('gender');
        my $cnt       = $row->get_column('cnt');

        ## 탈의를 key 한개로 묶는다
        if (   $status_id >= $OpenCloset::Status::STATUS_FITTING_ROOM1
            && $status_id <= $OpenCloset::Status::STATUS_FITTING_ROOM11 )
        {
            $waiting{$gender}{$OpenCloset::Status::STATUS_FITTING_ROOM1}
                += $cnt;
        }
        elsif ( $status_id == $OpenCloset::Status::STATUS_BOXED ) {
            ## 18: 포장, 44: 포장완료 는 같은 상태로 본다
            $waiting{$gender}{$OpenCloset::Status::STATUS_BOXING} += $cnt;
        }
        else {
            $waiting{$gender}{$status_id} = $cnt;
        }
    }

    return \%waiting;
}

1;
