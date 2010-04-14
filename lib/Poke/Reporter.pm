package Poke::Reporter;
use MooseX::Declare;

class Poke::Reporter
{
    with 'POEx::Role::SessionInstantiation';
    use aliased 'POEx::Role::Event';

    use POEx::Types(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::WorkerPool::WorkerEvents(':all');
    use MooseX::Types::Moose(':all');
    use Moose::Autobox;
    use Scalar::Util('blessed');
    use DateTime;

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

    has subscribed_workers =>
    (
        is => 'ro',
        isa => ArrayRef[SessionID],
        default => sub { [] },
        writer => '_set_subscribed_workers',
    );

    after _start is Event
    {
        $self->check_db();
    }

    method check_db
    {
        $self->schema->storage->dbh_do
        (
            sub
            {
                my ($storage, $dbh) = @_;
                unless ( @{ $dbh->table_info('', '', 'pokeresults', 'TABLE')->fetchall_arrayref } ) 
                {
                    $self->schema->deploy();
                }
            }
        );
    }

    method subscribe_to_worker(DoesWorker $worker)
    {
        if($self->subscribed_workers->any != $worker->ID)
        {
            $self->info("Subscribing to ${\$worker->ID}");
            my ($kernel, $palias) = ($self->poe->kernel, $worker->pubsub);
            $kernel->call($palias, 'subscribe', event_name => +PXWP_JOB_START, event_handler => 'job_started');
            $kernel->call($palias, 'subscribe', event_name => +PXWP_JOB_COMPLETE, event_handler => 'job_completed');
            $kernel->call($palias, 'subscribe', event_name => +PXWP_JOB_FAILED, event_handler => 'job_failed');
            $self->subscribed_workers->push($worker->ID);
        }
    }

    method unsubscribe_from_worker(DoesWorker $worker)
    {
        if($self->subscribed_workers->any = $worker->ID)
        {
            $self->info("Unsubscribing from ${\$worker->ID}");
            my ($kernel, $palias) = ($self->poe->kernel, $worker->pubsub);
            $kernel->call($palias, 'cancel', event_name => +PXWP_JOB_START);
            $kernel->call($palias, 'cancel', event_name => +PXWP_JOB_COMPLETE);
            $kernel->call($palias, 'cancel', event_name => +PXWP_JOB_FAILED);
            $self->_set_subscribed_workers($self->subscribed_workers->grep(sub{$worker->ID != $_}));
        }
    }

    method job_started(SessionID :$worker_id, DoesJob :$job) is Event
    {
        my $vals = 
        {
            job_name => blessed($job),
            job_uuid => $job->ID,
            job_start => DateTime->now(),
            job_status => 'inprogress'
        };
        
        $self->info("Job Started: ${\$job->ID}");
        $self->schema->result_set->new_result($vals)->insert();
    }

    method job_completed(SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
        $self->info("Job Completed: ${\$job->ID}");
        my $db_job = $self->schema->result_set->find($job->ID, { key => 'uuid_of_job' });
        $db_job->job_stop(DateTime->now());
        $db_job->job_status('success');
        $db_job->update();
    }

    method job_failed(SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
        $self->info("Job Failed: ${\$job->ID}\n\n $$msg");
        my $db_job = $self->schema->result_set->find($job->ID, { key => 'uuid_of_job' });
        $db_job->job_stop(DateTime->now());
        $db_job->job_status('fail');
        $db_job->update();
    }
}
