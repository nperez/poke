use Web::Simple('Poke::Web::Embeded');
{
    package Poke::Web::Embeded;

    dispatch
    {
        sub (GET)
        {
        },
        sub ()
        {
            return [ 404, [ 'Content-type', 'text/plain' ], [ 'Error: Not Found' ] ];
        }
    };
}

