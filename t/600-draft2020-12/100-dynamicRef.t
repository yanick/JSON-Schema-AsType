use 5.42.0;
use warnings;

use Test2::V1 -Pip;

use feature qw/ signatures/;

use JSON::Schema::AsType;
use JSON;

subtest 'A $dynamicRef to a $dynamicAnchor in the same schema resource behaves like a normal $ref to an $anchor' => sub {
	my $schema = JSON::Schema::AsType->new(
		draft  => '2020-12',
		schema => {
			'$id'     => 'https://test.json-schema.org/dynamicRef-dynamicAnchor-same-schema/root',
			'type'  => 'array',
			'items' => {
				'$dynamicRef' => '#items'
			},
			'$defs' => {
				'foo' => {
					'type'           => 'string',
					'$dynamicAnchor' => 'items'
				}
			},
		},
	);

	ok $schema->check( ['foo','bar'] ), 'all good';
	ok !$schema->check( ['foo',1] ), 'nope';

};

done_testing;
