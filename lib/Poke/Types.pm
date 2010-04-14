package Poke::Types;
use warnings;
use strict;

use MooseX::Types -declare =>
[qw/
    JobConfiguration
    JobConfigurations
    PokeConfig
/];
use MooseX::Types::Moose(':all');
use MooseX::Types::Structured(':all');
use Moose::Autobox;

subtype PokeConfig,
    as HashRef,
    where { $_->keys->length >= 5 && [qw/Poke Logger Schema Web/]->all eq $_->keys->any };

subtype JobConfiguration,
    as Tuple[Str, HashRef];

subtype JobConfigurations,
    as ArrayRef[JobConfiguration];

1;
