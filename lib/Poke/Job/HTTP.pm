package Poke::Job::HTTP;
use MooseX::Declare;

class Poke::Job::HTTP with Poke::Role::Job
{
    use Moose::Util::TypeConstraints;
    use MooseX::Types::URI('Uri');
    use HTTP::Request;
    use LWP::UserAgent;

    has uri =>
    (
        is => 'ro',
        isa => Uri,
        coerce => 1,
        required => 1,
    );

    has agent =>
    (
        is => 'ro',
        isa => class_type('LWP::UserAgent'),
        lazy_build => 1,
        handles => ['simple_request'],
    );

    sub _build_agent { return LWP::UserAgent->new(); }

    method setup
    {
        $self->agent();
    }

    method run
    {
        my $response = $self->simple_request($self->_build_request);
        die unless $response->is_success;
    }

    method _build_request
    {
        return HTTP::Request->new('GET', $self->uri);
    }
}
1;
