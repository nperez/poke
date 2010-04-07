package Poke;
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
