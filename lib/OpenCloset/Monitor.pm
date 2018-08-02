package OpenCloset::Monitor;
use Mojo::Base 'Mojolicious';

use Digest::SHA1 qw/sha1_hex/;
use Encode qw/encode_utf8/;
use HTTP::CookieJar;
use HTTP::Tiny;
use Mojo::JSON qw/j decode_json/;
use Net::IP::AddrRanges;
use Path::Tiny;
use Try::Tiny;
use WebService::Naver::TTS;

use OpenCloset::Monitor::Schema;
use OpenCloset::Schema;
use OpenCloset::Monitor::Status;
use OpenCloset::Size::Guess;

use version; our $VERSION = qv("v1.1.16");

our $PREFIX        = 'opencloset:storage';
our $REDIS_CHANNEL = 'opencloset:monitor';

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

has tts => sub {
    my $self   = shift;
    my $config = $self->config->{tts}{naver};
    WebService::Naver::TTS->new(
        id     => $config->{client_id},
        secret => $config->{client_secret}
    );
};

has guess => sub {
    my $self = shift;
    OpenCloset::Size::Guess->new(
        'DB',
        _time_zone => $self->config->{timezone},
        _schema    => $self->DB,
        _range     => 0,
    );
};

sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('OpenCloset::Monitor::Plugin::Helpers');
    $self->plugin('validator');
    $self->plugin('RemoteAddr');
    $self->plugin( Minion => { SQLite => $self->config->{minion}{SQLite} } );
    $self->secrets( [time] );
    $self->sessions->default_expiration(86400);

    $self->_assets;
    $self->_whitelist;
    $self->_public_routes;
    $self->_private_routes;
    $self->_add_task;
}

sub _assets {
    my $self = shift;

    $self->defaults( { jses => [], csses => [] } );
}

sub _whitelist {
    my $self = shift;

    $self->ranges->add( @{ $self->config->{whitelist} ||= [] } );
}

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/target_date')->to('API#target_dt')->name('api.target_date');
    $r->options('/target_date')->to('API#cors');
}

sub _private_routes {
    my $self   = shift;
    my $r      = $self->routes->under('/')->to('user#auth');
    my $region = $r->under('/region');

    $r->get('/')->to('dashboard#index')->name('index');
    $r->get('/statistics/elapsed')->to('statistics#elapsed')->name('elapsed');
    $r->get('/statistics/elapsed/:ymd')->to('statistics#elapsed_ymd');

    $r->get('/room')->to('dashboard#room')->name('rooms');
    $r->get('/select')->to('dashboard#select')->name('select');
    $r->get('/preparation')->to('dashboard#preparation')->name('preparation');
    $r->get('/repair')->to('dashboard#repair')->name('repair');
    $r->get('/online')->to('dashboard#online')->name('online');

    $r->post('/active')->to('dashboard#create_active');
    $r->delete('/active/:value')->to('dashboard#delete_active');

    $r->post('/events')->to('event#create');

    $r->websocket('/socket')->to('socket#socket')->name('socket');

    $r->put('/api/orders/:order_id')->to('API#update_order');
    $r->put('/api/users/:user_id')->to('API#update_user');
    $r->get('/api/status')->to('API#status');

    $r->get('/address')->to('API#address')->name('address');
    $r->post('/sms')->to('API#create_sms')->name('sms.create');
    $r->put('/brain')->to('API#update_brain')->name('brain.update');

    $r->get('/reservation')->to('reservation#index');
    $r->get('/reservation/visit')->to('reservation#visit');
    $r->get('/reservation/:ymd')->to('reservation#ymd');
    $r->get('/reservation/:ymd/search')->to('reservation#search');

    $region->get('/selects')->to('region#selects')->name('region.selects');
    $region->get('/rooms')->to('region#rooms')->name('region.rooms');
    $region->get('/status/repair')->to('region#status_repair');
    $region->get('/status/boxing')->to('region#status_boxing');
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
    my $rs = $self->DB->resultset('Order')->search(
        {
            status_id => { -in => [@OpenCloset::Monitor::Status::ACTIVE_STATUS] },
            online    => 0,
        },
        {
            select => ['status_id', 'user_info.gender', { count => 'status_id' }],
            as       => [qw/status_id gender cnt/],
            group_by => ['status_id', 'user_info.gender'],
            join     => ['booking', { user => 'user_info' }]
        }
    );

    my %waiting;
    while ( my $row = $rs->next ) {
        my $status_id = $row->get_column('status_id');
        my $gender    = $row->get_column('gender');
        my $cnt       = $row->get_column('cnt');

        ## 탈의를 key 한개로 묶는다
        if (   $status_id >= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1
            && $status_id <= $OpenCloset::Monitor::Status::STATUS_FITTING_ROOM15 )
        {
            $waiting{$gender}{$OpenCloset::Monitor::Status::STATUS_FITTING_ROOM1} += $cnt;
        }
        elsif ( $status_id == $OpenCloset::Monitor::Status::STATUS_BOXED ) {
            ## 18: 포장, 44: 포장완료 는 같은 상태로 본다
            $waiting{$gender}{$OpenCloset::Monitor::Status::STATUS_BOXING} += $cnt;
        }
        else {
            $waiting{$gender}{$status_id} = $cnt;
        }
    }

    return \%waiting;
}

=head2 _auth_opencloset

=cut

sub _auth_opencloset {
    my $self = shift;

    my $opencloset = $self->config->{opencloset};
    my $cookie     = path( $opencloset->{cookie} )->touch;
    my $cookiejar  = HTTP::CookieJar->new->load_cookies( $cookie->lines );
    my $http       = HTTP::Tiny->new( timeout => 3, cookie_jar => $cookiejar );

    my ($cookies) = $cookiejar->cookies_for( $opencloset->{uri} );
    my $expires   = $cookies->{expires};
    my $now       = DateTime->now->epoch;
    if ( !$expires || $expires < $now ) {
        my $email    = $opencloset->{email};
        my $password = $opencloset->{password};
        my $url      = $opencloset->{uri} . "/login";
        my $res      = $http->post_form( $url,
            { email => $email, password => $password, remember => 1 } );

        ## 성공일때 응답코드가 302 인데, 이는 실패했을때와 마찬가지이다.
        if ( $res->{status} == 302 && $res->{headers}{location} eq '/' ) {
            $cookie->spew( join "\n", $cookiejar->dump_cookies );
        }
        else {
            $self->app->log->error("Failed Authentication to Opencloset");
            $self->app->log->error("$res->{status} $res->{reason}");
        }
    }

    return $cookiejar;
}

sub _add_task {
    my $self   = shift;
    my $minion = $self->minion;
    $minion->reset;

    $minion->add_task(
        suggestion => sub {
            my ( $job, $user_id ) = @_;
            return unless $user_id;

            my $app   = $job->app;
            my $redis = $app->redis;
            $redis->del("$PREFIX:workers:$user_id");

            my $data = $redis->hget( "$PREFIX:clothes", $user_id );
            return if $data;

            my $user_info
                = $app->DB->resultset('UserInfo')->find( { user_id => $user_id } );
            return unless $user_info;
            return unless $user_info->height;
            return unless $user_info->weight;
            unless ( $user_info->waist ) {
                my $avg = $redis->hget( "$PREFIX:avg", $user_id );
                unless ($avg) {
                    $app->log->error("user($user_id) waist is required");
                    return;
                }

                $avg = decode_json($avg);
                my $waist = $avg->{waist};
                $app->log->info(
                    "Update user($user_id) user_info.waist(undefined) to avg($waist)");
                $user_info->update( { waist => $waist } )->discard_changes();
            }

            my $opencloset = $app->config->{opencloset};
            my $cookie     = $app->_auth_opencloset;
            my $http       = HTTP::Tiny->new( timeout => 20, cookie_jar => $cookie );
            my $url = $opencloset->{uri} . "/api/user/$user_id/search/clothes.json";

            $app->log->debug("[suggestion] --> Working on $user_id");
            $app->log->debug("[suggestion] Fetching $url ... ");

            my $res = $http->request( 'GET', $url );
            unless ( $res->{success} ) {
                $app->log->error("[suggestion] Failed to GET $url");
                $app->log->error("[suggestion] ! $res->{reason}");
                $app->log->error("[suggestion] ! Skip $user_id");
                return;
            }

            $redis->hset( "$PREFIX:clothes", $user_id, $res->{content} );

            ## 매번 요청에 성공할때마다 $PREFIX:clothes 의 expires 를 +1h 로 재설정
            $redis->expire( "$PREFIX:clothes", 60 * 60 * 1 );
            $redis->publish( "$REDIS_CHANNEL:user" => j( { sender => 'user' } ) );

            $app->log->debug("[suggestion] OK");
            $app->log->debug("[suggestion] Successfully published $user_id");
        }
    );

    our $TTS_EXT = '.mp3';
    $minion->add_task(
        tts => sub {
            my ( $job, $text ) = @_;
            return unless $text;

            my $task  = 'tts';
            my $app   = $job->app;
            my $redis = $app->redis;
            my $hex   = sha1_hex( encode_utf8($text) );

            my ( $dir, $file ) = $hex =~ m/^(..)(.+)$/;
            my $path = $app->home->child( 'public', 'tts', $dir, $file . $TTS_EXT );
            my $cache = path($path);
            $app->log->debug("[$task] $text");
            if ( $cache->exists ) {
                $app->log->debug("[$task] Cache hit \"$cache\"");
            }
            else {
                my $tts = $app->tts;
                my $mp3 = try {
                    $tts->tts( $text, UNLINK => 0, DIR => './db' );
                }
                catch {
                    chomp $_;
                    $app->log->error("[$task] Failed to convert \"$text\" to speech");
                    $app->log->error("[$task] $_");
                    return;
                };

                return unless $mp3;

                my $cache_dir = $cache->parent;
                $cache_dir->mkpath;
                $cache->spew_raw( $mp3->slurp_raw );
                try {
                    $mp3->remove;
                }
                catch {
                    $app->log->error("Failed to remove tempfile: $_");
                };
            }

            my $data = j(
                {
                    sender => 'tts',
                    path   => $app->url_for( "/tts/$dir/$file" . $TTS_EXT )->to_abs
                }
            );
            $redis->publish( "$REDIS_CHANNEL:tts" => $data );
        }
    );
}

1;
