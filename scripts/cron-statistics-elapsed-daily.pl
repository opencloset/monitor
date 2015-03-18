#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';

use Path::Tiny;
use DateTime::Tiny;

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

my $date = shift;
my ( $y, $m, $d );
my $where = 'TIMESTAMPDIFF(DAY, `timestamp`, NOW()) < ?';
if ($date) {
    ( $y, $m, $d ) = split /-/, $date;
    if ( $y && $m && $d ) {
        $where
            = "`timestamp` >= STR_TO_DATE('$y-$m-$d,','%Y-%m-%d') AND `timestamp` < DATE_ADD(STR_TO_DATE('$y-$m-$d,','%Y-%m-%d'), INTERVAL ? DAY)";
    }
    else {
        warn "Invalid date format: $date";
    }
}

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
            = int( $stat{ $user_info->gender }{$s0} );
    }
    else {
        $stat{ $user_info->gender }{$s0} = $elapsed;
    }
}


my $now = DateTime::Tiny->now;
my $ymd = substr $now->ymdhms, 0, 10;
my ( $year, $month ) = ( $now->year, sprintf( "%02s", $now->month ) );
if ( $y && $m && $d ) {
    $ymd   = "$y-$m-$d";
    $year  = $y;
    $month = $m;
}
my $tsv = path("statistics/elapsed/$year/$month/$ymd.tsv")->touchpath;
my @lines;

for my $key ( keys %stat ) {
    while ( my ( $status_id, $value ) = each %{ $stat{$key} } ) {
        $value = sprintf( "%.2f", $value / 60 );
        push @lines, "$key\t$status_id\t$value\n";
    }
}

$tsv->spew(@lines);

=pod

=head1 NAME

cron-statistics-elapsed-daily.pl

=head1 SYNOPSIS

    $ perl script/cron-statistics-elapsed-daily.pl               # default
    $ perl script/cron-statistics-elapsed-daily.pl 2015-01-01    # specific date

=cut
