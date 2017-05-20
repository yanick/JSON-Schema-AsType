use 5.20.0;

package Spaceship {

    use Moose;
    use Types::Standard qw/ Str /;

    use JSON::Schema::AsType;

    my $Coords = JSON::Schema::AsType->new( schema => {
            type => 'array',
            items => {
                type => 'number',
            },
            maxItems => 2,
            minItems => 2,
    });

    has name => (
        is => 'ro',
        isa => Str,
    );

    has coords => (
        is => 'ro',
        isa => $Coords->moose_type,
    );
}

my $ship = Spaceship->new(
    coords => [0,0],
    name => 'Musclebound Desolation',
);

use DDP;
p generate_schema( 'Spaceship' );


use experimental 'signatures', 'switch';

sub generate_schema($class) {
    my $meta = $class->meta;

    # for now assume all classes are of type 'object'
    my $schema = {
        name => $meta->name,
        type => 'object', 
    };


    for my $attr ( $meta->get_all_attributes ) {
        my %subschema;

        # if there is no constraint, it can be aaaanything
        if ( my $type = $attr->type_constraint ) {
            
            if ( $type->isa( 'Type::Tiny' ) ) {
                given( $type->name ) {
                    when( 'Str' ) {
                        $subschema{type} = 'string';
                    }
                    default {
                        die "I don't know how to deal with ", $type->name;
                    }
                }
            }
            elsif( $type->isa( 'JSON::Schema::AsType::MooseType' ) ) {
                %subschema = %{ $type->json_type->schema };
            }
        }

        $schema->{properties}{ $attr->name } = \%subschema;
    }

    return $schema;
}



