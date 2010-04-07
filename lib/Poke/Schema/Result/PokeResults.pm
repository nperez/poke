package Poke::Schema::Result::PokeResults;
use base 'DBIx::Class';
use DBIx::Class::InflateColumn::Object::Enum;

__PACKAGE__->load_components(qw/InflateColumn::DateTime InflateColumn::Object::Enum Core/);
__PACKAGE__->table('pokeresults');
__PACKAGE__->add_columns
(
    id =>
    {
        data_type => 'INTEGER',
        is_nullable => 0,
        is_auto_increment => 1,
        is_numeric => 1,
    },
    job_name =>
    {
        data_type => 'TEXT',
        is_nullable => 0,
    },
    job_uuid =>
    {
        data_Type => 'TEXT',
        is_nullable => 0,
    },
    job_start =>
    {
        data_type => 'datetime',
        is_nullable => 1,
    },
    job_stop =>
    {
        data_type => 'datetime',
        is_nullable => 1,
    },
    job_status =>
    {
        data_type => 'enum',
        is_enum => 1,
        extra =>
        {
            list => [qw/inprogress success fail/],
        },
    }
);

__PACKAGE__->set_primary_key('id');
