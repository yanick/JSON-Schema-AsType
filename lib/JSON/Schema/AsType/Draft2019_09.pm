package JSON::Schema::AsType::Draft2019_09;

use 5.42.0;
use warnings;

use feature ':5.42';
use JSON::Schema::AsType::Visit;

use JSON;

use Moose;

extends qw/ JSON::Schema::AsType /;

with 'JSON::Schema::AsType::Draft7::Keywords';

use feature qw/ signatures /;

my $_uri_port = 1;
has '+uri' => default => sub($self) {
	my $id =
	  eval { $self->schema->{'$id'} } // 'http://254.0.0.1:' . $_uri_port++;
	$self->clear_parent_schema;
	return $id;
};

has '+draft' => default => "2019-09";

has '+metaschema' => (
	default => sub($self) {
		_metaschema()
	}
);

around sub_schema => sub ( $orig, $self, $subschema, $uri ) {

	# ah AH, resolve the subschema id
	if ( my $id = $self->_has_id($subschema) ) {
        $uri = $self->resolve_uri($id) unless $subschema->{'$ref'};
	}
	$orig->( $self, $subschema, $uri );
};

sub _schema_trigger( $self, $schema, @ ) {
	JSON::Schema::AsType::Visit::visit(
		$schema,
		sub {
			my ( $key, $valueref, $context ) = @_;

			return unless ref $_ eq 'HASH';

			my $id = $self->_has_id($_) or return;

			$self->sub_schema( $_, $id );
			return;
		}
	);
}

sub _has_id ( $self, $schema = {} ) {
	return unless ref $schema eq 'HASH';
	return $schema->{'$id'};
}

sub _metaschema {
	state $METASCHEMA = __PACKAGE__->new(
		uri    => "https://json-schema.org/draft/2019-09/schema",
		schema => from_json join '', <DATA>
	);

	return $METASCHEMA;
}

__DATA__
{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/schema",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/core": true,
        "https://json-schema.org/draft/2019-09/vocab/applicator": true,
        "https://json-schema.org/draft/2019-09/vocab/validation": true,
        "https://json-schema.org/draft/2019-09/vocab/meta-data": true,
        "https://json-schema.org/draft/2019-09/vocab/format": false,
        "https://json-schema.org/draft/2019-09/vocab/content": true
    },
    "$recursiveAnchor": true,

    "title": "Core and Validation specifications meta-schema",
    "allOf": [
        {"$ref": "meta/core"},
        {"$ref": "meta/applicator"},
        {"$ref": "meta/validation"},
        {"$ref": "meta/meta-data"},
        {"$ref": "meta/format"},
        {"$ref": "meta/content"}
    ],
    "type": ["object", "boolean"],
    "properties": {
        "definitions": {
            "$comment": "While no longer an official keyword as it is replaced by $defs, this keyword is retained in the meta-schema to prevent incompatible extensions as it remains in common use.",
            "type": "object",
            "additionalProperties": { "$recursiveRef": "#" },
            "default": {}
        },
        "dependencies": {
            "$comment": "\"dependencies\" is no longer a keyword, but schema authors should avoid redefining it to facilitate a smooth transition to \"dependentSchemas\" and \"dependentRequired\"",
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$recursiveRef": "#" },
                    { "$ref": "meta/validation#/$defs/stringArray" }
                ]
            }
        }
    }
}
