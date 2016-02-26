package OpenCloset::Brain;

use Moo;

use Encode qw/encode_utf8 decode_utf8/;
use JSON;

has redis => ( is => 'ro' );
has events => ( is => 'rw', default => sub { {} } );

sub BUILD {
    my $self = shift;
    my $json = $self->redis->get('opencloset:storage') || '{}';
    $self->merge( decode_json( decode_utf8($json) ) );
    $self->on(
        'save',
        sub {
            my ( $me, $data ) = @_;    # me is self
            my $json = encode_json($data);
            $me->redis->set( 'opencloset:storage', encode_utf8($json) );
        }
    );
}

## autosave
sub DEMOLISH { shift->save }

sub emit {
    my ( $self, $name ) = ( shift, shift );    # not @_, should (shift, shift)
    if ( my $s = $self->events->{$name} ) {
        for my $cb (@$s) { $self->$cb(@_) }
    }

    return $self;
}

sub on {
    my ( $self, $name, $cb ) = @_;
    push @{ $self->events->{$name} ||= [] }, $cb;
    return $cb;
}

sub save {
    my $self = shift;
    $self->emit( 'save', $self->{data} );
}

sub close {
    my $self = shift;
    $self->save;
    $self->emit('close');
}

sub merge {
    my ( $self, $data ) = @_;
    for my $key ( keys %$data ) {
        $self->{data}{$key} = $data->{$key};
    }

    $self->emit( 'loaded', $self->{data} );
}

sub refresh {
    my $self = shift;
    $self->merge( decode_json( $self->source->slurp_utf8 || '{}' ) );
    return $self;
}

sub clear {
    my $self = shift;
    $self->{data} = {};
    return $self;
}

1;
