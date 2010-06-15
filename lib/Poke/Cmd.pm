package Poke::Cmd;
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
    use Poke::Web::Embedded;
    use Poke::Web::Middleware::Config;
    use Poke::Web::Middleware::Schema;
    use Poke::Web::Middleware::Logger;
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
                lifecycle => 'Singleton',
                block => sub
                {
                    $self->config_loader();
                }
            );

            service 'logger' =>
            (
                lifecycle => 'Singleton',
                class => 'Poke::Logger',
                dependencies => { config => depends_on('/config') }
            );

            service 'web_embedded' =>
            (
                lifecycle => 'Singleton',
                block => sub
                {
                    my $s = shift;
                    my $app = Poke::Web::Embedded->as_psgi_app();
                    $app = Poke::Web::Middleware::Config->wrap($app, config => $s->param('config'));
                    $app = Poke::Web::Middleware::Logger->wrap($app, logger => $s->param('logger'));
                    return Poke::Web::Middleware::Schema->wrap($app, schema => $s->param('schema'));
                },
                dependencies =>
                {
                    config => depends_on('/config'),
                    logger => depends_on('/logger'),
                    schema => depends_on('/schema'),
                }
            );
            
            service 'web' =>
            (
                lifecycle => 'Singleton',
                class => 'Poke::Web',
                block => sub
                {
                    my $s = shift;
                    Poke::Web->new
                    (
                        $s->param('config')->web_config->flatten,
                        logger => $s->param('logger'),
                        embedded => $s->param('embedded'),
                    )
                },
                dependencies =>
                {
                    config => depends_on('/config'),
                    logger => depends_on('/logger'),
                    embedded => depends_on('/web_embedded'),
                }
            );
            
            service 'reporter' =>
            (
                lifecycle => 'Singleton',
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
                lifecycle => 'Singleton',
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
                lifecycle => 'Singleton',
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

        $container->get_service('logger')->get()->info('Poke configuration loaded');
        return $container;
    }

    method run_it
    {
        if($self->no_fork)
        {
            $self->container->get_service('logger')->get()->info('Poke NOT forking');
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
                $self->container->get_service('logger')->get()->info('Poke forked successfully');
                $self->container->get_service('poke')->get()->start_poking();
            }
        }
    }
}

1;
__END__
