package Poke::Role::Job;
use MooseX::Declare;

role Poke::Role::Job
{
    use MooseX::Types::Moose(':all');
    use Scalar::Util('weaken');
    requires qw/setup run/;

    has frequency => (is => 'ro', isa => Int, default => sub { 60 });

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
