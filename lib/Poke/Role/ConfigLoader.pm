package Poke::Role::ConfigLoader;
use MooseX::Declare;

role Poke::Role::ConfigLoader
{
    use MooseX::Types::Moose(':all');
    use Poke::Types(':all');
    use Moose::Autobox;
    use Poke::Util;

    has config_source =>
    (
        is => 'ro', 
        isa => subtype Str, where { -e $_ },
        required => 1
    );

    has config =>
    (
        is => 'ro',
        isa => PokeConfig,
        traits => ['Hash'],
        handles =>
        {
            'poke_config' => [ get => 'Poke'],
            'log_config' => [ get => 'Log'],
        },
        lazy_build => 1,
    );
    method _build_config { Poke::Util->load_config($self->config_source) }

    has jobs_configuration =>
    (
        is => 'ro',
        isa => JobConfiguration, #ArrayRef[Tuple[ClassName, HashRef]],
        lazy_build => 1,
    );

    method _build_jobs_configuration
    {
        my $jcfg = $self->config
            ->kv
            ->grep(sub {[qw/Poke Log/]->all != $_->[0]});

        $jcfg->each(sub {Class::MOP::load_class($_->[0])});

        return $jcfg;
    }
    
}
1;
__END__
