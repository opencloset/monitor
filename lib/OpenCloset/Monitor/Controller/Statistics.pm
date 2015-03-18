package OpenCloset::Monitor::Controller::Statistics;
use Mojo::Base 'Mojolicious::Controller';

use Path::Tiny;

use OpenCloset::Brain;
use OpenCloset::Status;

has DB => sub { shift->app->DB };

sub elapsed { my $self = shift }

sub elapsed_ymd {
    my $self = shift;
    my $ymd  = $self->param('ymd');
    my ( $year, $month ) = split /-/, $ymd;
    my $tsv = path("statistics/elapsed/$year/$month/$ymd.tsv");
    return $self->error( 404, { str => "Not found data: $tsv" } )
        unless $tsv->exists;

    my %gdata;
    for my $line ( $tsv->lines( { chomp => 1 } ) ) {
        my ( $gender, $status_id, $value ) = split /\t/, $line;
        push @{ $gdata{daily}{$gender} ||= [] },
            { label => $OpenCloset::Status::MAP{$status_id}, value => $value };
        $gdata{daily}{sum}{$gender} += $value;
    }

    my %color = ( male => '#4d4dff', female => '#ff4d4d' );
    for my $gender (qw/male female/) {
        my @values;
        for my $data (
            sort status_reverse_order @{ $gdata{daily}{$gender} ||= [] } )
        {
            push @values,
                {
                x => $OpenCloset::Status::REVERSE_ORDER_MAP{ $data->{label} },
                y => $data->{value},
                };
        }
        push @{ $gdata{bars} ||= [] },
            {
            key    => "$ymd-$gender",
            values => [@values],
            color  => $color{$gender}
            };
    }

    my $brain   = OpenCloset::Brain->new;
    my $average = $brain->{data}{statistics}{elapsed_time};

    $color{male}   = '#0000ff';
    $color{female} = '#ff0000';
    for my $gender (qw/male female/) {
        my @values;
        for my $status_id ( sort status_order keys %{ $average->{$gender} } ) {
            push @values,
                {
                x => $OpenCloset::Status::ORDER_MAP{$status_id},
                y => $average->{$gender}{$status_id},
                };
        }
        push @{ $gdata{bars} ||= [] },
            {
            key    => "average-$gender",
            values => [@values],
            color  => $color{$gender}
            };
    }

    my $rs = $self->DB->resultset('Order')->search(
        { 'rental_date' => $ymd, },
        {
            select => ['user_info.gender', { count => 'user_info.gender' }],
            as     => [qw/gender cnt/],
            join     => [{ user => 'user_info' }],
            group_by => 'user_info.gender',
        }
    );

    my %visitor;
    while ( my $row = $rs->next ) {
        my ( $gender, $cnt )
            = ( $row->get_column('gender'), $row->get_column('cnt') );
        if ( $gender eq 'male' ) {
            $visitor{male} = $cnt;
        }
        elsif ( $gender eq 'female' ) {
            $visitor{female} = $cnt;
        }
    }

    $self->respond_to(
        json => { json => { gdata => {%gdata}, visitor => {%visitor} } } );
}

###
### Utilities
###

sub status_reverse_order {
    $OpenCloset::Status::REVERSE_ORDER_MAP{ $a->{label} }
        <=> $OpenCloset::Status::REVERSE_ORDER_MAP{ $b->{label} };
}

sub status_order {
    $OpenCloset::Status::ORDER_MAP{$a} <=> $OpenCloset::Status::ORDER_MAP{$b};
}

1;
