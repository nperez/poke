package Poke::Web;
use MooseX::Declare;
class Poke::Web
{
    use Moose::Util::TypeConstraints;
    use MooseX::Types::Moose(':all');
    use MooseX::Types::Structured(':all');
    use POEx::Types(':all');
    use POEx::Types::PSGIServer(':all');
    use Poke::Types(':all');

    use Socket;
    
    use aliased 'POEx::Role::Event';

    with 'POEx::Role::PSGIServer';

    has logger =>
    (
        is => 'ro',
        isa => 'Poke::Logger',
        required => 1,
        handles => [qw/ debug info notice warning error /]
    );

    has embedded =>
    (
        is => 'ro',
        isa => CodeRef,
        required => 1,
    );

    has _current_connections =>
    (
        is => 'ro',
        isa => HashRef[Tuple[Str, Int]],
        traits => ['Hash'],
        default => sub { +{ } },
        handles =>
        {
            '_add_connection' => 'set',
            '_get_connection' => 'get',
            '_del_connection' => 'delete',
        }
    );

    after _start
    {
        $self->register_service($self->embedded);
        $self->poe->kernel->sig('DIE', 'exception_handler');
    }
    
    method exception_handler(Str $sig, HashRef $ex) is Event
    {
        $self->poe->kernel->sig_handled();
        $self->error("Exception occured in $ex->{event}: $ex->{error_str}");
    }

    after handle_on_connect(GlobRef $socket, Str $address, Int $port, WheelID $id) is Event
    {
        $self->_add_connection("$socket", [Socket::inet_ntoa($address), $port]);
    }

    around generate_psgi_env(PSGIServerContext $c) returns (HashRef)
    {
        my $hash = $self->$orig($c);
        my $conn = $self->_get_connection('' . $c->{'wheel'}->get_input_handle);
        $hash->{'poke.web.connecting_ip'} = $conn->[0];
        $hash->{'poke.web.connecting_port'} = $conn->[1];
        return $hash;
    }

    before close(PSGIServerContext $c)
    {
        $self->_del_connection('' . $c->{'wheel'}->get_input_handle);
    }

}
1;
__END__
