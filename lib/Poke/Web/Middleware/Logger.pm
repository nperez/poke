package Poke::Web::Middleware::Logger;
use MooseX::Declare;

class Poke::Web::Middleware::Logger
{
    with 'Poke::Web::Middleware';
    use MooseX::Types::Moose(':all');

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Logger',
        prefix => 'logger',
    };

    after preinvoke()
    {
        $self->env->{'poke.web.middleware.logger'} = $self->logger;
    }
}
1;
__END__

