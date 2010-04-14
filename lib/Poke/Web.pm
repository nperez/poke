package Poke::Web;
use MooseX::Declare;
class Poke::Web
{
    use Poke::Web::Embedded;
    use POEx::Types::PSGIServer(':all');
    
    with 'POEx::Role::PSGIServer';

    with 'MooseX::Role::BuildInstanceOf' => 
    {
        target => 'Poke::Schema',
        prefix => 'schema',
        constructor => 'connect',
    };

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Logger',
        prefix => 'logger',
    };

    after _start
    {
        my $app = Poke::Web::Embedded->gen_app
        (
            logger => $self->logger,
            schema => $self->schema,
        );

        $self->psgi_app($app);
    }
}
1;
__END__
