package JSON::Schema::AsType::Draft4::Types;
# ABSTRACT: JSON-schema v4 keywords as types

=head1  SYNOPSIS

    use JSON::Schema::AsType::Draft4::Types '-all';

    my $type = Object & 
        Properties[
            foo => Minimum[3]
        ];

    $type->check({ foo => 5 });  # => 1
    $type->check({ foo => 1 });  # => 0

=head1 EXPORTED TYPES

        Minimum
        ExclusiveMinimum
        Maximum
        ExclusiveMaximum
        MultipleOf
        MaxItems
        MinItems

        Null
        Boolean
        Array
        Object
        String
        Integer
        Pattern
        Number

        Required

        Not

        MaxProperties
        MinProperties

        OneOf
        AllOf
        AnyOf

        MaxLength
        MinLength

        Items
        AdditionalItems

        Properties
        PatternProperties
        AdditionalProperties

        Dependencies
        Dependency

        Enum

        UniqueItems



=cut

use strict;
use warnings;

use Type::Utils -all;
use Types::Standard qw/ 
    Str StrictNum HashRef ArrayRef 
    Int
    Dict slurpy Optional Any
/;

use Type::Library
    -base,
    -declare => qw( 
        Minimum
        ExclusiveMinimum
        Maximum
        ExclusiveMaximum
        MultipleOf
        MaxItems
        MinItems

        Null
        Boolean
        Array
        Object
        String
        Integer
        Pattern
        Number

        Required

        Not

        MaxProperties
        MinProperties

        OneOf
        AllOf
        AnyOf

        MaxLength
        MinLength

        Items
        AdditionalItems

        Properties
        PatternProperties
        AdditionalProperties

        Dependencies
        Dependency

        Enum

        UniqueItems

    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON qw/ to_json from_json /;

use JSON::Schema::AsType;

declare AdditionalProperties,
    constraint_generator => sub {
        my( $known_properties, $type_or_boolean ) = @_;

        sub {
            return 1 unless Object->check($_);
            my @add_keys = grep { 
                my $key = $_;
                none {
                    ref $_ ? $key =~ $_ : $key eq $_
                } @$known_properties
            } keys %$_;

            if ( eval { $type_or_boolean->can('check') } ) {
                my $obj = $_;
                return all { $type_or_boolean->check($obj->{$_}) } @add_keys;
            }
            else {
                return not( @add_keys and not $type_or_boolean );
            }
        }
    };

declare UniqueItems,
    where {
        return 1 unless Array->check($_);
        @$_ == uniq map { to_json $_ , { allow_nonref => 1 } } @$_
    };

declare Enum,
    constraint_generator => sub {
        my @items = map { to_json( 
            ( StrictNum->check($_) ? 0+$_ : $_)
            => { allow_nonref => 1, canonical => 1 } ) } @_;

        sub {
            my $j = to_json $_ => { allow_nonref => 1, canonical => 1 };
            any { $_ eq $j } @items;
        }
    };

    # Dependencies[ foo => $type, bar => [ 'baz' ] ]
# TODO name of generated type should be better
declare Dependencies,
    constraint_generator => sub {
        my %deps = @_;

        return reduce { $a & $b } pairmap { Dependency[$a => $b] } %deps;
    };

    # Depencency[ foo => $type ]
declare Dependency,
    constraint_generator => sub {
        my( $property, $dep) = @_;

        sub {
            return 1 unless Object->check($_);
            return 1 unless exists $_->{$property};

            my $obj = $_;

            return all { exists $obj->{$_} } @$dep if ref $dep eq 'ARRAY';

            return $dep->check($_);
        }
    };

declare PatternProperties,
    constraint_generator => sub {
        my %props = @_;

        sub {
            return 1 unless Object->check($_);

            my $obj = $_;
            for my $key ( keys %props ) {
                return unless all { $props{$key}->check($obj->{$_}) } grep { /$key/ } keys %$_;
            }

            return 1;

        }
    };
declare Properties,
    constraint_generator => sub {
        my @types = @_;

        @types = pairmap { $a => Optional[$b] } @types;

        my $type = Dict[@types,slurpy Any];

        sub {
            return 1 unless Object->check($_);
            return $type->check($_);
        }
    };

declare Items,
    constraint_generator => sub {
        my $types = shift;

        sub {
            return 1 unless Array->check($_);

            return  ref $types eq 'ARRAY'
                ?  all { (! defined $_->[0]) or $_->[0]->check($_->[1]) } pairs zip @$types, @$_
                :  all { $types->check($_) } @$_
                ;
        }

    };

declare AdditionalItems,
    constraint_generator=> sub {
        if( @_ > 1 ) {
            my $to_skip = shift;
            my $schema = shift;
            return sub {
                all { $schema->check($_) } splice @$_, $to_skip; 
            }
        }
        else {
            my $size = shift;
            return sub { @$_ <= $size };
        }
    };

declare MaxLength,
    constraint_generator => sub {
        my $length = shift;
        sub {
            !String->check($_) or  $length >= length;
        }
    };

declare MinLength,
    constraint_generator => sub {
        my $length = shift;
        sub {
            !String->check($_) or  $length <= length;
        }
    };

declare AllOf,
    constraint_generator => sub {
        my @types = @_;
        sub {
            my $v = $_;
            all { $_->check($v) } @types;
        }
    };

declare AnyOf,
    constraint_generator => sub {
        my @types = @_;
        sub {
            my $v = $_;
            any { $_->check($v) } @types;
        }
    };

declare OneOf,
    constraint_generator => sub {
        my @types = @_;
        sub {
            my $v = $_;
            1 == grep { $_->check($v) } @types;
        }
    };

declare MaxProperties,
    constraint_generator => sub {
        my $nbr = shift;
        sub { !Object->check($_) or $nbr >= keys %$_; },
    };

declare MinProperties,
    constraint_generator => sub {
        my $nbr = shift;
        sub { 
            !Object->check($_) 
                or $nbr <= scalar keys %$_ 
        },
    };

declare Not,
    constraint_generator => sub {
        my $type = shift;
        sub { not $type->check($_) },
    };

declare String => as Str & ~StrictNum;

# ~Str or ~String?
declare Pattern,
    constraint_generator => sub {
        my $regex = shift;
        sub { !String->check($_) or /$regex/ },
    };


declare Object => as HashRef ,where sub { ref eq 'HASH' };

declare Required,
    as Object,
    constraint_generator => sub {
        my @keys = @_;
        sub {
            my $obj = $_;
            all { exists $obj->{$_} } @keys;
        }
    };

declare Array => as ArrayRef;

declare Boolean => where sub { ref =~ /JSON/ };

declare Number => as StrictNum & ~Boolean;

declare Integer => as Int & ~Boolean;

declare Null => where sub { not defined };

declare 'MaxItems',
    constraint_generator => sub {
        my $max = shift;

        return sub {
            ref ne 'ARRAY' or @$_ <= $max;
        };
    };

declare 'MinItems',
    constraint_generator => sub {
        my $min = shift;

        return sub {
            ref ne 'ARRAY' or @$_ >= $min;
        };
    };

declare 'MultipleOf',
    constraint_generator => sub {
        my $num =shift;

        return sub {
            !StrictNum->check($_)
                or ($_ / $num) !~ /\./;
        }
    };

declare Minimum,
    constraint_generator => sub {
        my $minimum = shift;
        return sub {
            ! StrictNum->check($_)
                or $_ >= $minimum;
        };
    };

declare ExclusiveMinimum,
    constraint_generator => sub {
        my $minimum = shift;
        return sub { 
            ! StrictNum->check($_)
                or $_ > $minimum;
        }
    };

declare Maximum,
    constraint_generator => sub {
        my $max = shift;
        return sub {
            ! StrictNum->check($_)
                or $_ <= $max;
        };
    };

declare ExclusiveMaximum,
    constraint_generator => sub {
        my $max = shift;
        return sub { 
            ! StrictNum->check($_)
                or $_ < $max;
        }
    };


0 and declare 'JsonSchemav4', as => JSON::Schema::AsType->new(
    specification => 'draft4',
    uri           => 'http://json-schema.org/draft-04/schema',
    schema        => from_json <<'END_JSON' )->type;
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

1;
