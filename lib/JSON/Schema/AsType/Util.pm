package JSON::Schema::AsType::Util;

use JSON::Schema::AsType;

use parent 'Exporter::Tiny';

use experimental 'signatures', 'switch';

our @EXPORT_OK = qw/ json_schema_type generate_schema /;

sub json_schema_type ($) {
    return JSON::Schema::AsType->new( schema => shift );
}


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

1;
