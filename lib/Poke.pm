package Poke;
use MooseX::Declare;

class Poke
{
    use POE;
    use aliased 'POEx::Role::Event';
    use POEx::Types(':all');
    use MooseX::Types::Moose(':all');
    use MooseX::Types::Structured(':all');
    use POEx::WorkerPool::Types(':all');
    use Poke::Types(':all');
    use TryCatch;
    use Poke::Util;
    use List::AllUtils('uniq');
    use Moose::Autobox;
    use Moose::Util;
    
    use POEx::WorkerPool::Worker traits => ['POEx::WorkerPool::Role::WorkerPool::OpenEndedWorker'];
    with 'POEx::Role::SessionInstantiation';

    has pool =>
    (
        is => 'ro',
        isa => 'POEx::WorkerPool',
        required => 1
    );

    has reporter =>
    (
        is => 'ro',
        isa => 'Poke::Reporter',
        required => 1,
    );

    has web =>
    (
        is => 'ro',
        isa => 'Poke::Web',
        required => 1,
    );
    
    has logger =>
    (
        is => 'ro',
        isa => 'Poke::Logger',
        required => 1,
        handles => [qw/ debug info notice warning error /]
    );

    has config =>
    (
        is => 'ro',
        isa => 'Poke::ConfigLoader',
        required => 1,
    );
    
    has stagger_low =>
    (
        is => 'ro',
        isa => Int,
        default => 5,
    );
    
    has stagger_high =>
    (
        is => 'ro',
        isa => Int,
        default => 10,
    );

    has retry_time =>
    (
        is => 'ro',
        isa => Int,
        default => 5,
    );

    after _start is Event
    {
        $self->info(q|Let's start poking!|);
        $self->set_up_sig_handlers();
        $self->yield('sub_workers');
        $self->yield('schedule_jobs');
    }

    method set_up_sig_handlers
    {
        $self->info('Setting up signal handlers');
        $self->poe->kernel->sig('DIE', 'exception_handler');
        $self->poe->kernel->sig('INT', 'shut_it_down');
        $self->poe->kernel->sig('TERM', 'shut_it_down');
        $self->poe->kernel->sig('HUP', 'shut_it_down');
    }

    method sub_workers is Event
    {
        $self->info('Subscribing to WorkerPool workers');
        $self->pool->workers->each_value
        (
            sub
            {
                $self->call($self->reporter->ID, 'subscribe_to_worker', $_);
            }
        );
    }
    
    method unsub_workers is Event
    {
        $self->info('Unsubscribing to WorkerPool workers');
        $self->pool->workers->each_value
        (
            sub
            {
                $self->call($self->reporter->ID, 'unsubscribe_from_worker', $_);
            }
        );
    }

    method schedule_jobs is Event
    {
        $self->info('Scheduling jobs for first run');
        $self->config->jobs_config
            ->each_value
            (
                sub
                {
                    $self->poe->kernel->delay_set
                    (
                        'run_job', 
                        $_->[1]->{frequency} 
                        + int(rand($self->stagger_low)) 
                        + $self->stagger_high, 
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
            my $job = $jcfg->[1]->{class}->new(%{$jcfg->[1]}, name => $jcfg->[0]);
            $self->info("Instantiated Job: ${\$job->ID}");
            my $alias = $self->pool->enqueue_job($job);
            $self->info('Job enqueued');
        }
        catch($err)
        {
            $self->error("Something horrible happened with ${\$jcfg->[0]}: $err");
        }

        $self->poe->kernel->delay_set
        (
            'run_job',
            $jcfg->[1]->{frequency},
            $jcfg
        );
    }

    method start_poking
    {
        POE::Kernel->run();
    }

    method exception_handler(Str $sig, HashRef $ex) is Event
    {
        $self->poe->kernel->sig_handled();
        $self->error("Exception occured in $ex->{event}: $ex->{error_str}");
    }

    method shut_it_down(Str $sig) is Event
    {
        $self->info("Received '$sig' and shutting down...");
        $self->pool->halt();
        $self->call($self->ID, 'unsub_workers');
        $self->call($self->web->ID, 'shutdown');
        $self->poe->kernel->alarm_remove_all();
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
    stagger_low = 5
    stagger_high = 10
    retry_delay = 5

    [WorkerPool]
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
