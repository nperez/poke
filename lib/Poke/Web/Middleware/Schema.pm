package Poke::Web::Middleware::Schema;
use MooseX::Declare;

class Poke::Web::Middleware::Schema
{
    with 'Poke::Web::Middleware';
    use MooseX::Types::Moose(':all');

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Schema',
        prefix => 'schema',
    };

    after preinvoke()
    {
        $self->env->{'poke.web.middleware.schema'} = $self->schema;
    }
}
1;
__END__
