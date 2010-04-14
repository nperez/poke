package Poke::Web::Middleware::Logger;
use MooseX::Declare;

class Poke::Web::Middleware::Logger
{
    with 'Poke::Web::Middleware';
    use MooseX::Types::Moose(':all');
    
    has logger => (is => 'ro', isa => 'Poke::Logger', required => 1);

    after preinvoke()
    {
        $self->env->{'poke.web.middleware.logger'} = $self->logger;
    }
}
1;
__END__

