use Web::Simple('Poke::Web::Embedded');
{
    package Poke::Web::Embedded;
    use HTML::Zoom;
    use Perl6::Junction;
    use DBIx::Class::ResultClass::HashRefInflator;
    use FindBin;
    use JSON::Any;

    my $logger;
    sub set_logger { shift; $logger = shift; }
    
    my $schema;
    sub set_schema { shift; $schema = shift; }
    
    my $conf;
    sub set_config { shift; $conf = shift; }

    sub build_job_link
    {
        my $jobname = shift;
        return qq|http://${\$conf->web_config->{host}}:${\$conf->web_config->{port}}/job_details?job_name=$jobname|;
    }

    dispatch
    {
        sub (GET + /)
        {
            my $jobs = [];
            foreach my $jobname (map { $_->[0] } @{$conf->jobs_config})
            {
                my $job = {};
                $job->{job_name} = $jobname;
                my $status = $schema->resultset('PokeResults')
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
                            ->replace_content(build_job_link($row->{job_name}))
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
            my ($self, $job_name) = @_;
            my $res = $schema->resultset('PokeResults')->search({ job_name => $job_name }, { order_by => { -desc => ['job_stop'] }, rows => 10 });
            $res->result_class('DBIx::Class::ResultClass::HashRefInflator');
            my $result = JSON::Any->objToJson([$res->all()]);

            return [ 200, [ 'Content-type', 'text/html' ], [$result] ];

        },
        sub ()
        {
            return [ 404, [ 'Content-type', 'text/plain' ], [ 'Error: Not Found' ] ];
        }
    };
}

Poke::Web::Embedded->run_if_script();
