#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';

use OpenCloset::Brain;
use OpenCloset::Schema;
use OpenCloset::Status;

my $schema = OpenCloset::Schema->connect(
    {
        dsn               => "dbi:mysql:opencloset:127.0.0.1",
        user              => 'opencloset',
        password          => 'opencloset',
        RaiseError        => 1,
        AutoCommit        => 1,
        quote_char        => q{`},
        mysql_enable_utf8 => 1,
        on_connect_do     => 'SET NAMES utf8',
    }
);

my %stat;
my $status_log = $schema->resultset('OrderStatusLog');

my $where = 'TIMESTAMPDIFF(MONTH, `timestamp`, NOW()) < ?';
$where
    .= ' AND status_id IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

my $logs = $status_log->search_literal(
    $where, 1,
    @OpenCloset::Status::ACTIVE_STATUS,
    { order_by => [qw/order_id timestamp/] }
);
my ( $o0, $o1, $s0, $s1, $t0, $t1, $elapsed );
while ( my $log = $logs->next ) {
    my $order     = $log->order;
    my $user_info = $order->user->user_info;

    $o0 = $o1 || $order->id;
    $o1 = $order->id;

    if ( $o0 != $o1 ) {
        undef $s0;
        undef $s1;
        undef $t0;
        undef $t1;
    }

    $s0 = $s1 || $log->status_id;
    $s1 = $log->status_id;

    $t0      = $t1 || $log->timestamp->epoch;
    $t1      = $log->timestamp->epoch;
    $elapsed = $t1 - $t0;

    next if $s0 == $s1;

    printf "%6s order(%s) status(%d) elapsed(%d)\n", $user_info->gender, $o1,
        $s0, $elapsed
        if $ENV{DEBUG};

    ## elapsed 가 너무크면 잘못된 데이터일 가능성이 있으므로 skip
    if ( $elapsed > ( 60 * 60 ) ) {
        print STDERR
            "Too long elapsed time: $elapsed order($o1) status_id($s0)\n";
        next;
    }

    ## 20 ~ 39: 탈의01 ~ 탈의20 상태는 모두 탈의
    $s0 = 20 if $s0 > 19 && $s0 < 40;

    if ( $stat{ $user_info->gender }{$s0} ) {
        $stat{ $user_info->gender }{$s0} += $elapsed;
        $stat{ $user_info->gender }{$s0} /= 2;
        $stat{ $user_info->gender }{$s0}
            = sprintf( "%.2f", $stat{ $user_info->gender }{$s0} / 60 );
    }
    else {
        $stat{ $user_info->gender }{$s0} = sprintf( "%.2f", $elapsed / 60 );
    }
}

my $brain = OpenCloset::Brain->new;
$brain->{data}{statistics}{elapsed_time} = {%stat};
