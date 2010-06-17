package Poke::Web::Middleware::Config;
use MooseX::Declare;

class Poke::Web::Middleware::Config
{
    with 'Fancy::Middleware';
    use MooseX::Types::Moose(':all');
    
    has config => (is => 'ro', isa => 'Poke::ConfigLoader', required => 1);

    after preinvoke()
    {
        $self->env->{'poke.web.middleware.config'} = $self->config;
    }
}
1;
__END__

