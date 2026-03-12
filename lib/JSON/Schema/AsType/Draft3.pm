package JSON::Schema::AsType::Draft3;

use 5.42.0;
use warnings;

use JSON;

use Moose;

use feature ':5.42';

use JSON::Schema::AsType::Visit;

extends qw/ JSON::Schema::AsType /;

with 'JSON::Schema::AsType::Draft3::Keywords';

use feature qw/ signatures /;

has '+draft' => default => 3;

my $_uri_port = 1;
has '+uri' => default => sub($self) {
	my $id = eval {$self->schema->{id}} // 'http://254.0.0.1:'.$_uri_port++;
	$self->clear_parent_schema;
	return $id;
};

has '+spec' => (
	default => sub($self) {
		metaschema();
	}
);

sub _has_id ($self,$schema = {} ) {
	return unless ref $schema eq 'HASH';
	return $schema->{id};
}

sub _schema_trigger($self,$schema,@) {
	JSON::Schema::AsType::Visit::visit( $schema, sub {
		my ( $key, $valueref, $context ) = @_;

		return unless ref $_ eq 'HASH';

		return unless $_->{id};

		$self->sub_schema($_,$_->{id});
	});
};

sub metaschema {
	state $METASCHEMA = __PACKAGE__->new(
		uri => "https://json-schema.org/draft-03/schema",
		schema => from_json join '', <DATA>,
	);

	return $METASCHEMA;
}

around sub_schema => sub ($orig,$self,$subschema,$uri) {
    # ah AH, resolve the subschema id
    if(my $id = $self->_has_id($subschema)) {
        $uri = $self->resolve_uri($id) unless $subschema->{'$ref'};
    }
    $orig->($self,$subschema,$uri);
};

__DATA__
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
