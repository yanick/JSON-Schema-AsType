use 5.20.0;

package Spaceship {

    use Moose;
    use Types::Standard qw/ Str /;

    use JSON::Schema::AsType::Util qw/ json_schema_type /;

    my $Coords = json_schema_type {
            type => 'array',
            items => {
                type => 'number',
            },
            maxItems => 2,
            minItems => 2,
    };

    has name => (
        is => 'ro',
        isa => Str,
    );

    has coords => (
        is => 'ro',
        isa => $Coords->moose_type,
    );
}

# change values and see the validation fail
my $ship = Spaceship->new(
    coords => [0,0],
    name => 'Musclebound Desolation',
);

use DDP;
use JSON::Schema::AsType::Util qw/ generate_schema /;

p generate_schema( 'Spaceship' );





