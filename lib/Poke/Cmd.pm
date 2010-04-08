package Poke::Cmd;
use MooseX::Declare;

class Poke::Cmd with MooseX::Getopt
{
    use Poke;
    use Moose::Util::TypeConstraints;
    has config => (is => 'ro', isa => subtype 'Str', where { -e $_ }, required => 1);
    has no_fork => (is => 'ro', isa => 'Bool', default => 0);

    method run_it
    {
        if($self->no_fork)
        {
            Poke->new(config_source => $self->config)->start_poking();
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
                Poke->new(config_source => $self->config)->start_poking();
            }
        }
    }
}

1;
__END__
