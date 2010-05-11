package Poke::Cmd;
sub POE::Kernel::CATCH_EXCEPTIONS () { 0 }
use MooseX::Declare;

class Poke::Cmd
{
    with 'MooseX::Getopt';
    
    use Bread::Board;
    use Moose::Util::TypeConstraints();
    use Moose::Autobox;
    use POEx::WorkerPool;
    use Poke;
    use Poke::Web;
    use Poke::Logger;
    use Poke::Schema;
    use Poke::Reporter;
    use Poke::ConfigLoader;

    has config => (is => 'ro', isa => Moose::Util::TypeConstraints::subtype('Str', Moose::Util::TypeConstraints::where { -e $_ }), required => 1);
    has config_loader => (init_arg => undef, is => 'ro', isa => 'Poke::ConfigLoader', lazy_build => 1);
    has no_fork => (is => 'ro', isa => 'Bool', default => 0);
    has container => (is => 'ro', isa => 'Bread::Board::Container', lazy_build => 1);

    method _build_config_loader
    {
        return Poke::ConfigLoader->new(config_source => $self->config);
    }

    method _build_container
    {
        my $container = container 'poke' => as
        {
            service 'schema' =>
            (
                block => sub
                {
                    my %cfg = shift->param('config')->schema_config()->flatten;
                    Poke::Schema->connect
                    (
                        @cfg{qw/dsn user password/}, { AutoCommit => 1}
                    );
                },
                dependencies => { config => depends_on('/config') }
            );

            service 'config' => 
            (
                block => sub
                {
                    $self->config_loader();
                }
            );

            service 'logger' =>
            (
                class => 'Poke::Logger',
                dependencies => { config => depends_on('/config') }
            );
            
            service 'web' =>
            (
                class => 'Poke::Web',
                block => sub
                {
                    my $s = shift;
                    Poke::Web->new
                    (
                        $s->param('config')->web_config->flatten,
                        logger => $s->param('logger'),
                        schema => $s->param('schema'),
                    )
                },
                dependencies =>
                {
                    config => depends_on('/config'),
                    logger => depends_on('/logger'),
                    schema => depends_on('/schema'),
                }
            );
            
            service 'reporter' =>
            (
                class => 'Poke::Reporter',
                dependencies =>
                {
                    config => depends_on('/config'),
                    logger => depends_on('/logger'),
                    schema => depends_on('/schema'),
                }
            );

            service 'pool' =>
            (
                block => sub
                {
                    my $s = shift;
                    POEx::WorkerPool->new
                    (
                        $s->param('config')->pool_config->flatten,
                        job_classes => $s->param('config')->jobs_config->map(sub{$_->[1]->{class}})
                    );
                },
                dependencies => 
                {
                    config => depends_on('/config'),
                }

            );
            
            service 'poke' =>
            (
                block => sub
                {
                    my $s = shift;
                    Poke->new
                    (
                        $s->param('config')->poke_config->flatten,
                        pool => $s->param('pool'),
                        logger => $s->param('logger'),
                        reporter => $s->param('reporter'),
                        web => $s->param('web'),
                        config => $s->param('config'),
                    );
                },
                dependencies =>
                {
                    config => depends_on('/config'),
                    pool => depends_on('/pool'),
                    logger => depends_on('/logger'),
                    reporter => depends_on('/reporter'),
                    web => depends_on('/web'),
                }
            );
        };

        $container->get_service('logger')->get()->info("Poke configuration loaded\n");
        return $container;
    }

    method run_it
    {
        if($self->no_fork)
        {
            $self->container->get_service('poke')->get()->start_poking();
        }
        else
        {
            my $pid = fork();
            die "Forking failed: $!" unless defined $pid;

            if($pid)
            {
                exit;
            }
            else
            {
                $self->container->get_service('poke')->get()->start_poking();
            }
        }
    }
}

1;
__END__
