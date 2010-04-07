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

    with 'MooseX::Role::BuildInstanceOf' => 
    {
        target => 'Poke::Schema',
        prefix => 'schema',
        constructor => 'connect',
    };

    method subscribe_to_worker {}
    method unsubscribe_from_worker {}

    method job_started(SessionID :$worker_id, DoesJob :$job) is Event
    {
    }

    method job_completed(SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
    }

    method job_failed(SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
    }
}
