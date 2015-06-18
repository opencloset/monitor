package OpenCloset::Monitor::Controller::Socket;
use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util;

=head1 METHODS

=head2 socket

    # socket
    WS /socket

=cut

sub socket {
    my $self = shift;

    $self->app->log->debug('WebSocket opened');
    $self->inactivity_timeout(300);
    Scalar::Util::weaken($self);

    my $log      = $self->app->log;
    my $redis_ch = $self->app->redis_channel;
    $self->on(
        message => sub {
            my ( $self, $msg ) = @_;
            $log->debug("[ws] < $msg");

            if ( my ($channel) = $msg =~ /^\/subscribe:? +([a-z]+)/i ) {
                $self->redis->subscribe(
                    ["$redis_ch:$channel"],
                    sub {
                        my ( $redis, $err ) = @_;
                        $log->error("[REDIS ERROR] subscribe error: $err")
                            if $err;
                    }
                );
            }
        }
    );

    $self->on(
        finish => sub {
            my ( $self, $code, $reason ) = @_;
            $log->debug("WebSocket closed with status $code");
            delete $self->stash->{redis};
        }
    );

    $self->redis->on(
        message => sub {
            my ( $redis, $message, $ch ) = @_;
            return if $ch !~ /$redis_ch/;
            return unless $self;
            $self->send($message);
        }
    );
}

1;
