package Poke::Logger;
use MooseX::Declare;

class Poke::Logger
{
    with 'MooseX::LogDispatch';
    with 'Poke::Role::ConfigLoader';

    has log_dispatch_conf =>
    (
        is => 'ro',
        isa => 'HashRef',
        lazy_build => 1,
    );

    method _build_log_dispatch_conf
    {
        if($self->log_config)
        {
            return $self->log_config;
        }
        
        return
        +{
            class => 'Log::Dispatch::File',
            min_level => 'info',
            filename => 'poked.log',
            mode => '>>',
            close_after_write => 1,
            newline => 1,
        };
    }

    has +logger => ( handles => [qw/ debug info notice warning error /] );
}
