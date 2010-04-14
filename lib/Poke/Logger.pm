package Poke::Logger;
use MooseX::Declare;

class Poke::Logger
{
    with 'MooseX::LogDispatch::Levels';
    
    has config =>
    (
        is => 'ro',
        isa => 'Poke::ConfigLoader',
        predicate => 'has_config',
    );

    has log_dispatch_conf =>
    (
        is => 'ro',
        isa => 'HashRef',
        lazy_build => 1,
    );

    method _build_log_dispatch_conf
    {
        if($self->has_config)
        {
            my %hash = %{$self->config->logger_config};
            return \%hash;
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
}
