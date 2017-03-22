package JSON::Schema::AsType::Draft3;
# ABSTRACT: Role processing draft3 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

Importing this module auto-populate the Draft3 schema in the
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

use JSON::Schema::AsType;

use JSON;

my $JsonObject = declare 'JsonObject', as HashRef() & ~Object();

use JSON::Schema::AsType::Draft3::Types '-all';

with 'JSON::Schema::AsType::Draft4' => {
    -excludes => [qw/ _keyword_properties _keyword_required _keyword_type /]
};

sub _keyword_properties {
    my( $self, $properties ) = @_;

    my @props = pairmap { {
        my $schema = $self->sub_schema($b);
        my $p = declare "Property", as $schema->type;
        $p = Optional[$p] unless $b->{required};
        $a => $p
    }}  %$properties;

    my $type = Dict[@props,slurpy Any];

    return (~$JsonObject) | $type;
}

sub _keyword_disallow {
    Disallow[ $_[0]->_keyword_type($_[1]) ];
}


sub _keyword_extends {
    my( $self, $extends ) = @_;

    my @extends = ref $extends eq 'ARRAY' ? @$extends : ( $extends );

    return Extends[ map { $self->sub_schema($_)->type } @extends];
}

sub _keyword_type {
    my( $self, $struct_type ) = @_;

    return if $struct_type eq 'any';

    my $notBoolean = declare as Any, where { ref( $_ ) !~ /JSON/ };
    my $notNumber = declare as Any, where { not StrictNum->check($_) };
    my $Boolean = declare as Any, where { ref($_) =~ /JSON/ };
    my $Null = declare as Any, where { ! defined $_ };

    return declare "TypeInteger", as Int & $notBoolean if $struct_type eq 'integer';
    return StrictNum & $notBoolean if $struct_type eq 'number';
    return  Str & $notNumber if $struct_type eq 'string';
    return  HashRef if $struct_type eq 'object';
    return  ArrayRef if $struct_type eq 'array';
    return  $Boolean if $struct_type eq 'boolean';
    return  $Null if $struct_type eq 'null';

    if( my @types = eval { @$struct_type } ) {
        return reduce { $a | $b } map { ref $_ ? $self->sub_schema($_)->type : $self->_keyword_type($_) } @types;
    }

    die "unknown type '$struct_type'";
}

sub _keyword_divisibleBy {
    my( $self, $divisibleBy ) = @_;

    DivisibleBy[$divisibleBy];
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

                return ref $deps ? $deps->check($obj) : exists $obj->{$deps};
            };
    }

    return $type;
}

JSON::Schema::AsType->new(
    draft_version => '3',
    uri           => 'http://json-schema.org/draft-03/schema',
    schema        => from_json <<'END_JSON' )->type;
{
    "$schema": "http://json-schema.org/draft-03/schema#",
    "id": "http://json-schema.org/draft-03/schema#",
    "type": "object",
    
    "properties": {
        "type": {
            "type": [ "string", "array" ],
            "items": {
                "type": [ "string", { "$ref": "#" } ]
            },
            "uniqueItems": true,
            "default": "any"
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
        
        "additionalProperties": {
            "type": [ { "$ref": "#" }, "boolean" ],
            "default": {}
        },
        
        "items": {
            "type": [ { "$ref": "#" }, "array" ],
            "items": { "$ref": "#" },
            "default": {}
        },
        
        "additionalItems": {
            "type": [ { "$ref": "#" }, "boolean" ],
            "default": {}
        },
        
        "required": {
            "type": "boolean",
            "default": false
        },
        
        "dependencies": {
            "type": "object",
            "additionalProperties": {
                "type": [ "string", "array", { "$ref": "#" } ],
                "items": {
                    "type": "string"
                }
            },
            "default": {}
        },
        
        "minimum": {
            "type": "number"
        },
        
        "maximum": {
            "type": "number"
        },
        
        "exclusiveMinimum": {
            "type": "boolean",
            "default": false
        },
        
        "exclusiveMaximum": {
            "type": "boolean",
            "default": false
        },
        
        "minItems": {
            "type": "integer",
            "minimum": 0,
            "default": 0
        },
        
        "maxItems": {
            "type": "integer",
            "minimum": 0
        },
        
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        
        "minLength": {
            "type": "integer",
            "minimum": 0,
            "default": 0
        },
        
        "maxLength": {
            "type": "integer"
        },
        
        "enum": {
            "type": "array",
            "minItems": 1,
            "uniqueItems": true
        },
        
        "default": {
            "type": "any"
        },
        
        "title": {
            "type": "string"
        },
        
        "description": {
            "type": "string"
        },
        
        "format": {
            "type": "string"
        },
        
        "divisibleBy": {
            "type": "number",
            "minimum": 0,
            "exclusiveMinimum": true,
            "default": 1
        },
        
        "disallow": {
            "type": [ "string", "array" ],
            "items": {
                "type": [ "string", { "$ref": "#" } ]
            },
            "uniqueItems": true
        },
        
        "extends": {
            "type": [ { "$ref": "#" }, "array" ],
            "items": { "$ref": "#" },
            "default": {}
        },
        
        "id": {
            "type": "string",
            "format": "uri"
        },
        
        "$ref": {
            "type": "string",
            "format": "uri"
        },
        
        "$schema": {
            "type": "string",
            "format": "uri"
        }
    },
    
    "dependencies": {
        "exclusiveMinimum": "minimum",
        "exclusiveMaximum": "maximum"
    },
    
    "default": {}
}
END_JSON
