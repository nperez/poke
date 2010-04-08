package Poke;
use MooseX::Declare;

class Poke
{
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
    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'POEx::WorkerPool',
        prefix => 'pool',
    };

    with 'MooseX::Role::BuildInstanceOf' =>
    {
        target => 'Poke::Reporter',
        prefix => 'reporter',
    };

    has config_source =>
    (
        is => 'ro', 
        isa => subtype Str, where { -e $_ },
        required => 1
    );

    has config =>
    (
        is => 'ro',
        isa => PokeConfig,
        traits => ['Hash'],
        handles =>
        {
            'poke_config' => [ get => 'Poke'],
        },
        lazy_build => 1,
    );
    method _build_config { Poke::Util->load_config($self->config_source) }


    has jobs_configuration =>
    (
        is => 'ro',
        isa => JobConfiguration, #ArrayRef[Tuple[ClassName, HashRef]],
        lazy_build => 1,
    );

    method _build_jobs_configuration
    {
        my $jcfg = $self->config
            ->kv
            ->grep(sub {$_->[0] != 'Poke'});

        $jcfg->each(sub {Class::MOP::load_class($_->[0])});

        return $jcfg;
    }

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
    
    has reporter_attrs =>
    (
        is => 'ro',
        isa => ArrayRef[Str],
        lazy_build => 1,
    );

    method _build_reporter_attrs 
    {
        my $attrs = [Poke::Reporter->meta->get_all_attributes()]->map(sub{ $_->name });
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
        $self->spin_up_constituents();
        $self->go();
    }

    method spin_up_constituents
    {
        $self->pool();
        $self->reporter();
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
            ->push( {job_classes => $self->jobs_configuration->map(sub{ $_->[0] })} );

        my $reporter_args = $self->poke_config
            ->kv
            ->grep( sub {$self->reporter_attrs->any = $_->[0]} );
        
       $self->pool_args($pool_args);
       $self->reporter_args($reporter_args);
    }

    method go
    {
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
        try
        {
            my $worker = $self->pool->get_next_worker();
            my $job = $jcfg->[0]->new(%{$jcfg->[1]});
            $worker->enqueue_job($job);
            $worker->start_processing();
        }
        catch(NoAvailableWorkers $err)
        {
            $self->poe->kernel->set_delay('run_job', $self->retry_delay, $jcfg);
        }
        catch($err)
        {
        }
    }
}
1;
__END__

=head1 SYNOPSIS

    ## SomeJob.pm reachable via @INC
    package SomeJob;
    use Moose;
    use MyFrob;
    with 'Poke::Role::Job';
    
    has some_argument => (is => 'ro', isa => 'Int', required => 1);
    has frob => (is => 'ro', isa => 'Object', lazy_build => 1);
    sub _build_frob { MyFrob->new(); }

    sub setup { shift->frob; } # build our frobber across the process boundary

    sub run { my $self = shift; $self->frob->awesome_sauce($self->some_argument); }

    ## /path/to/some/file.ini
    
    [Poke]
    max_workers = 3
    dsn = dbi:SQLite:thingy.db
    user = ''
    password = ''
    httpd = yes
    httpd_port = 12345

    [SomeJob]
    frequency = 60
    some_argument = 42
    
    ## Now spin it up
    poked --config /path/to/some/file.ini

=head1 DESCRIPTION

Poke is a monitoring framework. It pokes things to see if they are alive and then reports back. It is intended to be used through its shiny little command 'poked' with a config file and some jobs. Poke comes with only a couple of simple jobs, but should be plenty for people that just want to do simple stats on uptime for a webservice. Results are stored in a database that you configure Poke to use. You can get a simple display of those results if you turn on the httpd.
