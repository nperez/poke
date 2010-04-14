use Web::Simple('Poke::Web::Embeded');
{
    package Poke::Web::Embeded;
    use HTML::Zoom;
    use DBIx::Class::ResultClass::HashRefInflator;
    use Poke::Web::Middleware::Logger;
    use Poke::Web::Middleware::Schema;
    use Poke::Web::ConfigLoader;

my $html = <<HTML;
<html>
<head>
</head>
<body>
<div class="main_container">
<div class="service">
<table>
<thead><tr><th>Job Name</th><th>Job Status</th><th>Job Start</th><th>Job Stop</th></thead>
<tbody><tr><td class="job_name"/><td class="job_status"/><td class="job_start"/><td class="job_stop"/></tr></tbody>
<tfoot></tfoot>
</table>
</div>
</div>
</body>
</html>

HTML

    dispatch
    {
        sub (GET)
        {
            my $output = HTML::Zoom
                ->from_html($html)
                ->select('.main_container')
                ->repeat_content
                (
                    [
                        map
                        {
                            my $row = $_;
                            my @subs;
                            foreach my $key (keys %$row)
                            {
                                push
                                (
                                    @subs,
                                    sub
                                    {
                                        my $foo = shift;
                                        $foo->select('.service')
                                        ->select(".$key")
                                        ->replace_content($row->{$key});
                                    }
                                );
                            }
                            @subs;
                        }
                        map
                        {
                            
                        }
                        @{
                            my $result = $self->env->{'poke.web.middleware.schema'}
                                ->resultset('PokeResults');
                            $result->result_class('DBIx::Class::ResultClass::HashRefInflator');
                            $result->all();
                        }
                    ]
                )
                ->to_fh();
            return [ 200, [ 'Content-type', 'text/plain' ], $output ];
        },
        sub ()
        {
            return [ 404, [ 'Content-type', 'text/plain' ], [ 'Error: Not Found' ] ];
        }
    };

    sub gen_app
    {
        shift if ref $_[0];

        my $app = Poke::Web::Embedded->run_if_script();

        my %config = @_;
        if(!%config)
        {
            require FindBin;
            my $loaded_config = Poke::Web::ConfigLoader->new(config_source => "$FindBin::Bin/poke.ini");
            $app = Poke::Web::Middleware::Logger->wrap($app, logger_args => [%{$loaded_config->logger_config}]);
            $app = Poke::Web::Middleware::Schema->wrap($app, schema_args => [%{$loaded_config->schema_config}]);
        }
        else
        {
            $app = Poke::Web::Middleware::Logger->wrap($app, logger => $config{logger});
            $app = Poke::Web::Middleware::Schema->wrap($app, schema => $config{schema});
        }

        
        return $app;
    }
}

Poke::Web::Embeded->gen_app();
