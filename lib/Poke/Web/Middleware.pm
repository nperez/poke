package Poke::Web::Middleware;
use MooseX::Declare;

role Poke::Web::Middleware
{
    use POEx::Types::PSGIServer(':all');
    use MooseX::Types::Moose(':all');
    use Scalar::Util('weaken');

    has app => (is => 'ro', isa => CodeRef, required => 1);
    has response => (is => 'ro', isa => PSGIResponse, writer => 'set_response');
    has env => (is => 'rw', isa => HashRef);

    method wrap(ClassName $class: CodeRef $app, @args)
    {
        my $self = $class->new(app => $app, @args);
        return $self->to_app;
    }

    method call(HashRef $env)
    {
        $self->env($env);
        $self->preinvoke();
        $self->invoke();
        $self->postinvoke();
        return $self->response;
    }

    method preinvoke()
    {
        return;
    }

    method invoke()
    {
        $self->set_response(($self->app)->($self->env));
    }

    method postinvoke()
    {
        return;
    }

    method to_app()
    {   
        return sub { $self->call(@_) };
    }
}

1;
__END__
