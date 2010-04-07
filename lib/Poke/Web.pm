package Poke::Web;
use MooseX::Declare;
class Poke::Web
{
    use MooseX::Types::Moose(':all');
    use Moose::Util::TypeConstraints;
    use POE::Component::Server::PSGI;
    use Poke::Web::Embedded;
    
    has port => (is => 'ro', isa => Int, required => 1);
    has address => (is => 'ro', isa => Str, required => 1);

    has httpd =>
    (
        is => 'ro',
        isa => class_type('POE::Component::Server::PSGI'),
        lazy_build => 1,
    );

    method _build_httpd
    {
        my $httpd = POE::Component::Server::PSGI->new
        (
            host => $self->address,
            port => $self->port,
        );

        $httpd->register_service(Poke::Embedded::HTTPD->run_if_script());

        return $httpd;
    }
}
1;
__END__
