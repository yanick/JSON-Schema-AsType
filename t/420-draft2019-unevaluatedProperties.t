use Test2::V1 -Pip;

use JSON::Schema::AsType;
use JSON;

subtest 'unevaluatedProperties on its own' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2019-09',
		schema => {
			'$schema' => 'https://json-schema.org/draft/2019-09/schema',
			'unevaluatedProperties' => {
				'minLength' => 3,
				'type'      => 'string'
			},
			'type' => 'object'
		}
	);

	ok !$schema->check( { foo => 'fo' } ), 'fo is too short';
};

subtest 'unevaluatedProperties with adjacent properties' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2019-09',
		schema => {
			'unevaluatedProperties' => JSON::false,
			'type' => 'object',
			properties => {
				foo => { type => 'string' }
			}
		}
	);

	ok $schema->check( { foo => 'foo' } ), 'nothing unevaluated';
};

subtest 'unevaluatedProperties with adjacent patternProperties' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2019-09',
		schema => {
			'unevaluatedProperties' => JSON::false,
			'type' => 'object',
			patternProperties => {
				'^foo' => { type => 'string' }
			}
		}
	);

	ok $schema->check( { foo => 'foo' } ), 'nothing unevaluated';
};

subtest 'unevaluatedProperties with adjacent additionalProperties' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2019-09',
		schema => {
			'unevaluatedProperties' => JSON::false,
			additionalProperties => JSON::true,
			'type' => 'object',
		}
	);

	ok $schema->check( { foo => 'foo' } ), 'nothing unevaluated';
};

subtest 'allOf keeps the scope' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2019-09',
		schema => {
			properties => { foo => { type => 'string' } },
			unevaluatedProperties => JSON::false,
			type => 'object',
			allOf => [
				{ properties => { bar => { type => 'string' } } }
			]
		}
	);
	
	note $schema->type->display_name;

	ok $schema->check( { foo => 'foo', bar => 'bar' } ), 'nothing unevaluated';
};


done_testing;
