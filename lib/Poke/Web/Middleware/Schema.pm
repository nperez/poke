package Poke::Web::Middleware::Schema;
use MooseX::Declare;

class Poke::Web::Middleware::Schema
{
    with 'Fancy::Middleware';
    use MooseX::Types::Moose(':all');
    
    has schema => (is => 'ro', isa => 'Poke::Schema', required => 1);

    after preinvoke()
    {
        $self->env->{'poke.web.middleware.schema'} = $self->schema;
    }
}
1;
__END__
