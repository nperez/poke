package Poke::Web;
use MooseX::Declare;
class Poke::Web
{
    use Poke::Web::Embedded;
    use POEx::Types(':all');
    use POEx::Types::PSGIServer(':all');
    use Poke::Types(':all');
    
    use aliased 'POEx::Role::Event';

    with 'POEx::Role::PSGIServer';

    has logger =>
    (
        is => 'ro',
        isa => 'Poke::Logger',
        required => 1,
        handles => [qw/ debug info notice warning error /]
    );

    has schema =>
    (
        is => 'ro',
        isa => 'Poke::Schema',
        required => 1, 
    );

    has config =>
    (
        is => 'ro',
        isa => 'Poke::ConfigLoader',
        required => 1,
    );

    after _start
    {
        Poke::Web::Embedded->set_logger($self->logger);
        Poke::Web::Embedded->set_schema($self->schema);
        Poke::Web::Embedded->set_config($self->config);
        $self->register_service(Poke::Web::Embedded->run_if_script());
        $self->poe->kernel->sig('DIE', 'exception_handler');
    }
    
    method exception_handler(Str $sig, HashRef $ex) is Event
    {
        $self->poe->kernel->sig_handled();
        $self->error("Exception occured in $ex->{event}: $ex->{error_str}");
    }

}
1;
__END__
