#!/usr/bin/env perl
use strict;
use warnings;
use DateTime;
use Directory::Queue;
use Encode qw/decode_utf8/;
use HTTP::CookieJar;
use HTTP::Tiny;
use Mojo::JSON qw/j/;
use Mojo::Redis2;
use Path::Tiny;

use FindBin qw($Bin);
use lib "$Bin/../lib";

STDOUT->autoflush(1);

our $PREFIX = 'opencloset:storage';

my $config = require "$Bin/../monitor.conf";

my $redis = Mojo::Redis2->new;
$redis->on( error => sub { print STDERR "[REDIS ERROR]: $_[1]" } );

my $redis_channel = 'opencloset:monitor';
my $dirq          = Directory::Queue->new( path => $config->{queue}{path} );
my $opencloset    = $config->{opencloset};

while (1) {
    for ( my $name = $dirq->first(); $name; $name = $dirq->next() ) {
        next unless $dirq->lock($name);

        my $user_id = $dirq->get($name);

        my $data = $redis->hget( "$PREFIX:clothes", $user_id );

        if ($data) {
            $dirq->remove($name);
            next;
        }

        my $cookie = _auth_opencloset($config);
        my $http   = HTTP::Tiny->new( timeout => 10, cookie_jar => $cookie );
        my $url    = $opencloset->{uri} . "/api/user/$user_id/search/clothes.json";

        print "--> Working on $user_id\n";
        print "Fetching $url ... ";

        my $res = $http->request( 'GET', $url );
        unless ( $res->{success} ) {
            print STDERR "Failed\n";
            print STDERR "! $res->{reason}\n";
            print STDERR "! Skip $user_id\n";
            $dirq->remove($name);
            next;
        }

        print "OK\n";

        $redis->hset( "$PREFIX:clothes", $user_id, $res->{content} );
        $redis->publish( "$redis_channel:user" => j( { sender => 'user' } ) );
        $dirq->remove($name);

        print "Successfully published $user_id\n";
    }

    sleep(1);
}


sub _auth_opencloset {
    my $config     = shift;
    my $opencloset = $config->{opencloset};
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
            print STDERR "Failed Authentication to Opencloset\n";
            print STDERR "$res->{status} $res->{reason}\n";
        }
    }

    return $cookiejar;
}
