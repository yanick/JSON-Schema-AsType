package JSON::Schema::AsType::Draft4;
# ABSTRACT: Role processing draft4 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

Importing this module auto-populate the Draft4 schema in the
L<JSON::Schema::AsType> schema cache.

=cut

use strict;
use warnings;

use Moose::Role;

use Type::Utils;
use Scalar::Util qw/ looks_like_number /;
use List::Util qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int Object slurpy Dict Optional slurpy /; 

use JSON::Schema::AsType::Draft4::Types '-all';

use JSON;

use JSON::Schema::AsType;

my $JsonObject = declare 'JsonObject', as HashRef() & ~Object();

__PACKAGE__->meta->add_method( '_keyword_$ref' => sub {
        my( $self, $ref ) = @_;

        return Type::Tiny->new(
            name => 'Ref',
            display_name => "Ref($ref)",
            constraint => sub {
                $self->resolve_reference($ref)->check($_);
            },
            message => sub { 
                my $schema = $self->resolve_reference($ref);

                join "\n", "ref schema is " . to_json($schema->schema), @{$schema->validate_explain($_)} 
            }
        );
} );

sub _keyword_pattern {
    my( $self, $pattern ) = @_;

    (~Str) | declare 'Pattern', where { /$pattern/ };
}

sub _keyword_enum {
    my( $self, $enum ) = @_;

    my @enum = map { to_json $_ => { allow_nonref => 1, canonical => 1 } } @$enum;

    declare 'Enum' => where {
        my $j = to_json $_ => { allow_nonref => 1, canonical => 1 };
        any { $_ eq $j } @enum;
    }, message {
        my $j = to_json $_ => { allow_nonref => 1, canonical => 1 };
        "Value '$j' doesn't match any of the enum items:" . join " ", map { "'$_'" } @enum;
    };

}

sub _keyword_uniqueItems {
    my( $self, $unique ) = @_;

    return unless $unique;  # unique false? all is good

    declare 'UniqueItems',
        where {
            my $size = eval { @$_ } or return 1;
            $size == uniq map { to_json $_ , { allow_nonref => 1 } } @$_
        };

}

sub _keyword_dependencies {
    my( $self, $dependencies ) = @_;

    my $type = Any;

    while( my ( $key, $deps ) = each %$dependencies ) {
        $deps = $self->sub_schema( $deps) if ref $deps eq 'HASH';
        $type = declare as $type,
            where { 
                my $obj = $_;

                return 1 if ref ne 'HASH' or ! $_->{$key};

                if ( ref $deps eq 'ARRAY' ) {
                    return all { exists $obj->{$_} } @$deps;
                }

                return $deps->check($obj);
            };
    }

    return $type;
}

sub _keyword_additionalProperties {
    my( $self, $addi ) = @_;

    my $add_schema;
    $add_schema = $self->sub_schema($addi) if ref $addi eq 'HASH';

    ~$JsonObject | declare where { 
        my $obj = $_;

        my @keys = keys %$obj;
        @keys = grep { 
            my $key = $_;
            none { $key eq $_ } eval { keys %{ $self->schema->{properties} } }
                and none { $key =~ /$_/ } eval { keys %{ $self->schema->{patternProperties} } }
        }  @keys;

        return all { $add_schema->check($obj->{$_}) } @keys if $add_schema;

        return not( @keys and not $addi );
    }
}

sub _keyword_patternProperties {
    my( $self, $properties ) = @_;

    my %prop_schemas = pairmap {
        $a => $self->sub_schema($b)->type
    } %$properties;

    my $type = Any;

    while( my($p,$s)= each%prop_schemas ) {
        $type = declare as $type,
            where { 
                my @keys = grep { /$p/ } keys %$_;
                for my $k ( @keys ) {
                    return 0 unless $s->check($_->{$k});
                }
                return 1;
            };
    }

    return (~$JsonObject) | $type;
}

sub _keyword_properties {
    my( $self, $properties ) = @_;

    my @props = pairmap { {
        my $schema = $self->sub_schema($b);
        $a => Optional[declare "Property", as $schema->type ];
    }}  %$properties;

    my $type = Dict[@props,slurpy Any];

    return (~$JsonObject) | $type;
}

sub _keyword_maxProperties {
    my( $self, $max ) = @_;

    (~HashRef) | declare 'MaxProperties', where { keys(%$_) <= $max };
}

sub _keyword_minProperties {
    my( $self, $min ) = @_;

    ~ HashRef | declare 'MinProperties', where { keys(%$_) >= $min };
}

sub _keyword_required {
    my( $self, $required ) = @_;

    reduce { $a & $b }
    map { 
        my $p = $_;
        declare 'Required', where { exists $_->{$p} };
    } @$required;

}

sub _keyword_not {
    my( $self, $not_schema ) = @_;
    ~ $self->sub_schema( $not_schema )->type;
}

sub _keyword_oneOf {
    my( $self, $options ) = @_;

    my @x = map { $self->sub_schema( $_ ) } @$options;

    declare 'OneOf', where {
        my $t = $_;
        1 == grep { $_->check($t) } @x
    };
}


sub _keyword_anyOf {
    my( $self, $options ) = @_;

   return reduce { $a | $b } map { $self->sub_schema($_)->type } @$options;
}

sub _keyword_allOf {
    my( $self, $options ) = @_;

   return reduce { $a & $b } map { $self->sub_schema($_)->type } @$options;
}

sub _keyword_type {
    my( $self, $struct_type ) = @_;

    my $notBoolean = declare as Any, where { ref( $_ ) !~ /JSON/ };
    my $notNumber = declare as Any, where { not StrictNum->check($_) };
    my $Boolean = declare as Any, where { ref($_) =~ /JSON/ };

    return declare "TypeInteger", as Int & $notBoolean if $struct_type eq 'integer';
    return StrictNum & $notBoolean if $struct_type eq 'number';
    return  Str & $notNumber if $struct_type eq 'string';
    return  HashRef if $struct_type eq 'object';
    return  ArrayRef if $struct_type eq 'array';
    return  $Boolean if $struct_type eq 'boolean';
    return  Null if $struct_type eq 'null';

    if( my @types = eval { @$struct_type } ) {
        return reduce { $a | $b } map { $self->_keyword_type($_) } @types;
    }

    die "unknown type '$struct_type'";
}

sub _keyword_multipleOf {
    my( $self, $num ) = @_;

    MultipleOf[$num];
}

sub _keyword_maxItems {
    my( $self, $max ) = @_;

    MaxItems[$max];
}

sub _keyword_minItems {
    my( $self, $min ) = @_;

    MinItems[$min];
}

sub _keyword_maxLength {
    my( $self, $max ) = @_;

    declare "MaxLength",
        where {
            !Str->check($_)
            or StrictNum->check($_)
            or $max >= length
        };
}

sub _keyword_minLength {
    my( $self, $min ) = @_;

    return MinLength[$min];
}

sub _keyword_maximum {
    my( $self, $maximum ) = @_;

    return $self->schema->{exclusiveMaximum}
        ? ExclusiveMaximum[$maximum]
        : Maximum[$maximum];

}

sub _keyword_minimum {
    my( $self, $minimum ) = @_;

    if ( $self->schema->{exclusiveMinimum} ) {
        return ExclusiveMinimum[$minimum];
    }

    return Minimum[$minimum];
}

sub _keyword_additionalItems {
    my( $self, $s ) = @_;

    unless($s) {
        my $items = $self->schema->{items} or return;
        return if ref $items eq 'HASH';  # it's a schema, nevermind
        my $size = @$items;
        return declare 'AdditionalItems' => where {
            @$_ <= $size
        };
    }

    my $schema = $self->sub_schema($s);

    my $to_skip  = @{ $self->schema->{items} };

    declare 'AdditionalItems', where {
        my @array = @$_;
        all { $schema->check($_) } splice @array, $to_skip; 
    };


}

sub _keyword_items {
    my( $self, $items ) = @_;

    if( ref $items eq 'HASH' ) {
        my $type = $self->sub_schema($items)->type;
        return (~ArrayRef) | declare 'Items', where {
            all { $type->check($_) } @$_;
        };
    }

    # TODO forward declaration not workie
    my @types;
    for ( @$items ) {
        push @types, $self->sub_schema($_);
    }


    declare 'Items', where {
        all { (! defined $_->[0]) or $_->[0]->check($_->[1]) } pairs zip @types, @$_; 
    };

}


our $SpecSchema = JSON::Schema::AsType->new(
    specification => 'draft4',
    uri           => 'http://json-schema.org/draft-04/schema',
    schema        => from_json <<'END_JSON' );
{
    "id": "http://json-schema.org/draft-04/schema#",
    "$schema": "http://json-schema.org/draft-04/schema#",
    "description": "Core schema meta-schema",
    "definitions": {
        "schemaArray": {
            "type": "array",
            "minItems": 1,
            "items": { "$ref": "#" }
        },
        "positiveInteger": {
            "type": "integer",
            "minimum": 0
        },
        "positiveIntegerDefault0": {
            "allOf": [ { "$ref": "#/definitions/positiveInteger" }, { "default": 0 } ]
        },
        "simpleTypes": {
            "enum": [ "array", "boolean", "integer", "null", "number", "object", "string" ]
        },
        "stringArray": {
            "type": "array",
            "items": { "type": "string" },
            "minItems": 1,
            "uniqueItems": true
        }
    },
    "type": "object",
    "properties": {
        "id": {
            "type": "string",
            "format": "uri"
        },
        "$schema": {
            "type": "string",
            "format": "uri"
        },
        "title": {
            "type": "string"
        },
        "description": {
            "type": "string"
        },
        "default": {},
        "multipleOf": {
            "type": "number",
            "minimum": 0,
            "exclusiveMinimum": true
        },
        "maximum": {
            "type": "number"
        },
        "exclusiveMaximum": {
            "type": "boolean",
            "default": false
        },
        "minimum": {
            "type": "number"
        },
        "exclusiveMinimum": {
            "type": "boolean",
            "default": false
        },
        "maxLength": { "$ref": "#/definitions/positiveInteger" },
        "minLength": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        "additionalItems": {
            "anyOf": [
                { "type": "boolean" },
                { "$ref": "#" }
            ],
            "default": {}
        },
        "items": {
            "anyOf": [
                { "$ref": "#" },
                { "$ref": "#/definitions/schemaArray" }
            ],
            "default": {}
        },
        "maxItems": { "$ref": "#/definitions/positiveInteger" },
        "minItems": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        "maxProperties": { "$ref": "#/definitions/positiveInteger" },
        "minProperties": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "required": { "$ref": "#/definitions/stringArray" },
        "additionalProperties": {
            "anyOf": [
                { "type": "boolean" },
                { "$ref": "#" }
            ],
            "default": {}
        },
        "definitions": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "properties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "patternProperties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "dependencies": {
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$ref": "#" },
                    { "$ref": "#/definitions/stringArray" }
                ]
            }
        },
        "enum": {
            "type": "array",
            "minItems": 1,
            "uniqueItems": true
        },
        "type": {
            "anyOf": [
                { "$ref": "#/definitions/simpleTypes" },
                {
                    "type": "array",
                    "items": { "$ref": "#/definitions/simpleTypes" },
                    "minItems": 1,
                    "uniqueItems": true
                }
            ]
        },
        "allOf": { "$ref": "#/definitions/schemaArray" },
        "anyOf": { "$ref": "#/definitions/schemaArray" },
        "oneOf": { "$ref": "#/definitions/schemaArray" },
        "not": { "$ref": "#" }
    },
    "dependencies": {
        "exclusiveMaximum": [ "maximum" ],
        "exclusiveMinimum": [ "minimum" ]
    },
    "default": {}
}
END_JSON
