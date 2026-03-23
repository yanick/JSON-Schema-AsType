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


done_testing;
