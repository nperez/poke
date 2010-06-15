package Poke::Web::Embedded;
use HTML::Zoom;
use Perl6::Junction;
use DBIx::Class::ResultClass::HashRefInflator;
use FindBin;
use JSON::Any;
use Web::Simple(__PACKAGE__);

use constant
{
    CONFIG => 'poke.web.middleware.config',
    SCHEMA => 'poke.web.middleware.schema',
    LOGGER => 'poke.web.middleware.logger',
    PSGI_ENV => -1,
};

sub build_job_link
{
    my ($conf, $jobname) = @_;
    return qq|http://${\$conf->web_config->{host}}:${\$conf->web_config->{port}}/job_details?job_name=$jobname|;
}

dispatch
{
    sub (GET + /)
    {
        my ($self, $env) = @_[0, +PSGI_ENV];
        
        $env->{+LOGGER}->info(q|Received request for '| . $env->{REQUEST_URI} . q|' at '| . localtime() . q|' from '| . $env->{'poke.web.connecting_ip'} . q|:| . $env->{'poke.web.connecting_port'}. q|'|);
        
        my $jobs = [];
        foreach my $jobname (map { $_->[0] } @{$env->{+CONFIG}->jobs_config})
        {
            my $job = {};
            $job->{job_name} = $jobname;
            my $status = $env->{+SCHEMA}->resultset('PokeResults')
                ->search({job_name => $jobname}, { order_by => { -desc => [qw/job_stop/] } })
                ->first();
            $job->{job_status} = $status->job_status()->value();
            $job->{job_start} = $status->job_start()->iso8601();
            $job->{job_stop} = $status->job_stop()->iso8601();
            push(@$jobs, $job);
        }

        my $repeat = 
        [
            map
            {
                my $row = $_;
                sub
                {
                    shift->select('.job_link')
                        ->replace_content(build_job_link($env->{'poke.web.middleware.config'}, $row->{job_name}))
                    ->select('.job_name')
                        ->replace_content($row->{job_name})
                    ->select('.job_status')
                        ->add_attribute('class', $row->{job_status})
                    ->select('.job_status')
                        ->replace_content($row->{job_status})
                    ->select('.job_start')
                        ->replace_content($row->{job_start})
                    ->select('.job_stop')
                        ->replace_content($row->{job_stop});
                },
            }
            @$jobs
        ];

        my $output = HTML::Zoom
            ->from_file("$FindBin::Bin/../html/index.html")
            ->select('.service_body')
            ->repeat_content($repeat)
            ->to_fh();

        return [ 200, [ 'Content-type', 'text/html' ], $output ];
    },
    sub (GET + /job_details + ?job_name=)
    {
        my ($self, $job_name, $env) = @_[0,1, +PSGI_ENV];

        $env->{+LOGGER}->info(q|Received request for '| . $env->{REQUEST_URI} . q|' at '| . localtime() . q|' from '| . $env->{'poke.web.connecting_ip'} . q|:| . $env->{'poke.web.connecting_port'}. q|'|);
        
        my $res = $env->{+SCHEMA}->resultset('PokeResults')->search({ job_name => $job_name }, { order_by => { -desc => ['job_stop'] }, rows => 10 });
        $res->result_class('DBIx::Class::ResultClass::HashRefInflator');
        my $result = JSON::Any->objToJson([$res->all()]);

        return [ 200, [ 'Content-type', 'text/html' ], [$result] ];

    },
    sub ()
    {
        return [ 404, [ 'Content-type', 'text/plain' ], [ 'Error: Not Found' ] ];
    }
};
