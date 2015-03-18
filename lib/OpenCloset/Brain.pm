package OpenCloset::Brain;

use Moo;

use JSON;
use Path::Tiny;

our $BRAIN_SOURCE = $ENV{OPENCLOSET_BRAIN} || '.opencloset.json';

has events => ( is => 'rw', default => sub { {} } );
has source => ( is => 'ro', default => sub { path($BRAIN_SOURCE)->touch } );

sub BUILD {
    my $self = shift;
    $self->{data} = {};
    $self->merge( decode_json( $self->source->slurp_utf8 || '{}' ) );
    $self->on(
        'save',
        sub {
            my ( $me, $data ) = @_;    # me is self
            $me->source->spew_utf8( encode_json($data) );
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
