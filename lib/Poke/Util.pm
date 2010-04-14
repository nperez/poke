package Poke::Util;
use MooseX::Declare;

class Poke::Util
{
    use Config::Any;
    method load_config(ClassName $class: Str $file)
    {
        my $cfg = Config::Any->load_files({ files => [$file], use_ext => 1 })->[0]->{$file};
        return $cfg;
    }
}

