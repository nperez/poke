package Poke::Role::Job;
use MooseX::Declare;

role Poke::Role::Job
{
    use Scalar::Util('weaken');
    requires qw/setup run/;

    method init_job
    {
        weaken($self);
        $self->setup(); 
        $self->enqueue_step
        (
            [
                sub{ $self->run() }, 
                [] 
            ]
        );
    }

    with 'POEx::WorkerPool::Role::Job';
}

1;
__END__
