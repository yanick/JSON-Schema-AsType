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

subtest 'A $dynamicRef to a $anchor in the same schema resource behaves like a normal $ref to an $anchor' => sub {
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
					'type'    => 'string',
					'$anchor' => 'items'
				}
			},
		},
	);

	ok $schema->check( ['foo','bar'] ), 'all good';
	ok !$schema->check( ['foo',1] ), 'nope';

};


subtest 'A $ref to a $dynamicAnchor' => sub {
    my $schema = JSON::Schema::AsType->new(
        draft  => '2020-12',
        schema => {
            'type'  => 'array',
            'items' => { '$ref' => '#items' },
            '$defs' => {
                'foo' => {
                    'type'           => 'string',
                    '$dynamicAnchor' => 'items'
                }
            },
        },
    );

    use DDP;
    p $schema->resolve_reference('#items')->type->check(1);
    p [$schema->all_schema_uris]->@*;



    ok $schema->check( [ 'foo',  'bar' ] ), 'all good';
    ok !$schema->check( [ 'foo', [] ] ),     'nope';

};

done_testing;
