package Poke::Web;
use MooseX::Declare;
class Poke::Web
{
    use Poke::Web::Embedded;
    use POEx::Types::PSGIServer(':all');
    
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

    after _start
    {
        Poke::Web::Embedded->set_logger($self->logger);
        Poke::Web::Embedded->set_schema($self->schema);
        $self->register_service(Poke::Web::Embedded->run_if_script());
    }
}
1;
__END__
