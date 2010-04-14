package Poke;
use MooseX::Declare;

class Poke
{
    use POE;
    use aliased 'POEx::Role::Event';
    use POEx::Types(':all')
    use MooseX::Types::Moose(':all');
    use MooseX::Types::Structured(':all');
    use POEx::WorkerPool::Types(':all');
    use Poke::Types(':all');
    use TryCatch;
    use Poke::Util;
    use List::AllUtils('uniq');
    use Moose::Autobox;

    with 'POEx::Role::SessionInstantiation';
    with 'Poke::Role::ConfigLoader';

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'POEx::WorkerPool',
        prefix => 'pool',
    };
    
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
    
    has +logger => ( handles => [qw/debug info notice warning error/] );
    
    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Web',
        prefix => 'web',
    }

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Reporter',
        prefix => 'reporter',
    };

    has pool_attrs =>
    (
        is => 'ro',
        isa => ArrayRef[Str],
        lazy_build => 1,
    );

    method _build_pool_attrs 
    {
        my $attrs = [POEx::WorkerPool->meta->get_all_attributes()]->map(sub{ $_->name });
        return uniq(@$attrs);
    }
    
    has stagger_range =>
    (
        is => 'ro',
        isa => Tuple[Int, Int],
        default => sub { [5,10] }
    );

    has retry_time =>
    (
        is => 'ro',
        isa => Int,
        default => 5,
    );

    after _start is Event
    {
        $self->setup_args_from_config();
        $self->info('Poke configuration loaded');
        $self->spin_up_constituents();
        $self->info(q|Let's start poking!|);
        $self->go();
    }

    method spin_up_constituents
    {
        $self->info('Spinning up the WorkerPool');
        $self->pool();
        $self->info('Spinning up the Reporter');
        $self->reporter();
        $self->info('Subscribing to WorkerPool workers');
        $self->pool->workers->each
        (
            sub
            {
                $self->reporter->subscribe_to_worker($_);
            }
        );
    }
    
    method setup_args_from_config
    {
        my $pool_args = $self->poke_config
            ->kv
            ->grep( sub {$self->pool_attrs->any = $_->[0]} )
            ->push( [job_classes => $self->jobs_configuration->map(sub{ $_->[0] })] );

       $self->pool_args([$pool_args->flatten_deep(2)]);
       $self->schema_args([$self->schema_config->flatten]);
       $self->logger_args([$self->logger_config->flatten]);
       $self->web_args([($self->web_config->flatten), schema => $self->schema, logger => $self->logger]);
       $self->reporter_args([schema => $self->schema, logger => $self->logger]);
    }

    method go
    {
        $self->info('Scheduling jobs for first run');
        $self->jobs_configuration->each
        (
            sub
            {
                $self->poe->kernel->set_delay
                (
                    'run_job', 
                    $_->[1]->frequency 
                    + int(rand($self->stagger_range->first)) 
                    + $self->stagger_range->last, 
                    $_ 
                );
            }
        );
    }

    method run_job(JobConfiguration $jcfg) is Event
    {
        $self->info("Trying to run Job: ${\$jcfg->[0]}");
        try
        {
            my $worker = $self->pool->get_next_worker();
            $self->info("Gathered next worker: ${\$worker->ID}");
            my $job = $jcfg->[0]->new(%{$jcfg->[1]});
            $self->info("Instantiated Job: ${\$job->ID}");
            $worker->enqueue_job($job);
            $self->info('Job enqueued');
            $worker->start_processing();
            $self->info('Go go go gadget worker!');
        }
        catch(NoAvailableWorkers $err)
        {
            $self->info('All workers are busy, requeing job to run a short time later');
            $self->poe->kernel->set_delay('run_job', $self->retry_delay, $jcfg);
        }
        catch($err)
        {
            $self->error("Something horrible happened with ${\$jcfg->[0]}: $err");
        }
    }

    method start_poking
    {
        POE::Kernel->run();
    }
}
1;
__END__

=head1 SYNOPSIS

    ## SomeJob.pm reachable via @INC
    package SomeJob;
    use Moose;
    use namespace::autoclean;
    use MyFrob;
    
    has some_argument => (is => 'ro', isa => 'Int', required => 1);
    has frob => (is => 'ro', isa => 'Object', lazy_build => 1);
    sub _build_frob { MyFrob->new(); }

    sub setup { shift->frob; } # build our frobber across the process boundary

    sub run { my $self = shift; $self->frob->awesome_sauce($self->some_argument); }
    
    with 'Poke::Role::Job';
    __PACKAGE__->meta->make_immutable();
    1;

    ## /path/to/some/file.ini
    
    [Poke]
    max_workers = 3

    [Schema]
    dsn = dbi:SQLite:thingy.db
    user = ''
    password = ''

    [Web]
    port = 12345
    host = localhost

    [Logger]
    class = Log::Dispatch::Syslog
    min_level = info
    facility = daemon
    ident = Poke!
    format = '[%p] %m'

    [SomeJob]
    frequency = 60
    some_argument = 42
    
    ## Now spin it up
    poked --config /path/to/some/file.ini

=head1 DESCRIPTION

Poke is a monitoring framework. It pokes things to see if they are alive and then reports back. It is intended to be used through its shiny little command 'poked' with a config file and some jobs. Poke comes with only a couple of simple jobs, but should be plenty for people that just want to do simple stats on uptime for a webservice. Results are stored in a database that you configure Poke to use. You can get a simple display of those results if you turn on the httpd.
