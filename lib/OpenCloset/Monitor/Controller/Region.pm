package OpenCloset::Monitor::Controller::Region;
use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 selects

    # region.selects
    GET /region/selects

=cut

sub selects {
    my $self = shift;

    # $self->render( template => '' );
}

=head2 rooms

    # region.rooms
    GET /region/rooms

=cut

sub rooms {
    my $self = shift;
}

=head2 room

    # region.room
    GET /region/rooms/:no

=cut

sub room {
    my $self = shift;
}

=head2 repair

    GET /region/status/repair

=cut

sub repair {
    my $self = shift;
}

=head2 boxed

    GET /region/status/boxed

=cut

sub boxed {
    my $self = shift;
}

1;
