package JSON::Schema::AsType::Draft4;

use 5.42.0;
use warnings;


use feature ':5.42';

use JSON;
# use Data::Visitor::Tiny;
use JSON::Schema::AsType::Visit;

use Moose;

extends qw/ JSON::Schema::AsType /;

with 'JSON::Schema::AsType::Draft4::Keywords';

use feature qw/ signatures /;

my $METASCHEMA = from_json join '', <DATA>;

has '+draft_version' => default => 4;

has '+spec' => (
	default => sub($self) {
		$self->new(
			registry => $self->registry,
			uri => "https://json-schema.org/draft-04/schema",
			schema => $METASCHEMA
		);
	}
);

has '+uri' => default => sub($self) {
	return unless $self->has_schema;
	my $id = $self->schema->{id} or return;
	$self->register_schema->( $id, $self );
	$self->clear_parent_schema;
};

sub _schema_trigger($self,$schema,@) {
	JSON::Schema::AsType::Visit::visit( $schema, sub {
		my ( $key, $valueref, $context ) = @_;

		return unless ref $_ eq 'HASH';

		return unless $_->{id};

		$self->sub_schema($_,$_->{id});
	});
};

__DATA__
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
