use 5.42.0;
use warnings;

use Test2::V1 -Pip;

use feature qw/ signatures/;

use JSON::Schema::AsType;
use JSON;

subtest
  'A $dynamicRef to a $dynamicAnchor in the same schema resource behaves like a normal $ref to an $anchor'
  => sub {
    my $schema = JSON::Schema::AsType->new(
        draft  => '2020-12',
        schema => {
            '$id' =>
              'https://test.json-schema.org/dynamicRef-dynamicAnchor-same-schema/root',
            'type'  => 'array',
            'items' => { '$dynamicRef' => '#items' },
            '$defs' => {
                'foo' => {
                    'type'           => 'string',
                    '$dynamicAnchor' => 'items'
                }
            },
        },
    );

    ok $schema->check( [ 'foo',  'bar' ] ), 'all good';
    ok !$schema->check( [ 'foo', 1 ] ),     'nope';

  };

subtest
  'A $dynamicRef to a $anchor in the same schema resource behaves like a normal $ref to an $anchor'
  => sub {
    my $schema = JSON::Schema::AsType->new(
        draft  => '2020-12',
        schema => {
            '$id' =>
              'https://test.json-schema.org/dynamicRef-dynamicAnchor-same-schema/root',
            'type'  => 'array',
            'items' => { '$dynamicRef' => '#items' },
            '$defs' => {
                'foo' => {
                    'type'    => 'string',
                    '$anchor' => 'items'
                }
            },
        },
    );

    ok $schema->check( [ 'foo',  'bar' ] ), 'all good';
    ok !$schema->check( [ 'foo', 1 ] ),     'nope';

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

    ok $schema->check( [ 'foo',  'bar' ] ), 'all good';
    ok !$schema->check( [ 'foo', [] ] ),    'nope';
};

subtest 'recursive part is valid against the root' => sub {
    my $schema = JSON::Schema::AsType->new(
        draft  => '2020-12',
        schema => {
            '$dynamicAnchor' => 'meta',
            '$schema' => 'https://json-schema.org/draft/2020-12/schema',
            '$id'     =>
              'https://test.json-schema.org/relative-dynamic-reference/root',
            'type'       => 'object',
            'properties' => { 'foo' => { 'const' => 'pass' } },
            '$ref'       => 'extended',
            '$defs'      => {
                'extended' => {
                    'properties'     => { 'bar' => { '$ref' => 'bar' } },
                    '$dynamicAnchor' => 'meta',
                    '$id'            =>
                      'https://test.json-schema.org/relative-dynamic-reference/extended',
                    'type' => 'object'
                },
                'bar' => {
                    '$id' =>
                      'https://test.json-schema.org/relative-dynamic-reference/bar',
                    'type'       => 'object',
                    'properties' =>
                      { 'baz' => { '$dynamicRef' => 'extended#meta' } }
                }
            },
        },
    );

    ok $schema->check(
        {   'foo' => 'pass',
            'bar' => { 'baz' => { 'foo' => 'pass' } }
        }
      ),
      'all good';
};

subtest 'The recursive part is valid against the root' => sub {
    my $schema = JSON::Schema::AsType->new(
        draft  => '2020-12',
        schema => {
            '$id' =>
              'https://test.json-schema.org/relative-dynamic-reference/root',
            '$schema' => 'https://json-schema.org/draft/2020-12/schema',
            '$ref'    => 'extended',
            '$dynamicAnchor' => 'meta',
            'type'       => 'object',
            'properties' => { 'foo' => { 'const' => 'pass' } },
            '$defs'          => {
                'bar' => {
                    'properties' =>
                      { 'baz' => { '$dynamicRef' => 'extended#meta' } },
                    'type' => 'object',
                    '$id'  =>
                      'https://test.json-schema.org/relative-dynamic-reference/bar'
                },
                'extended' => {
                    'type'           => 'object',
                    'properties'     => { 'bar' => { '$ref' => 'bar' } },
                    '$dynamicAnchor' => 'meta',
                    '$id'            =>
                      'https://test.json-schema.org/relative-dynamic-reference/extended'
                }
            },
        }
    );

    ok $schema->check(
        {   'foo' => 'pass',
            'bar' => { 'baz' => { 'foo' => 'pass' } }
        }
      ),
      'all good';

    ok $schema->validate(
        {   'foo' => 'pass',
            'bar' => { 'baz' => { 'foo' => 'fail' } }
        }
      ),
      'should fail';
};

done_testing;
