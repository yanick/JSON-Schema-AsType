use strict;
use warnings;

use Test2::V1 -Pip; 

use JSON::Schema::AsType;

my $schema = JSON::Schema::AsType->new( schema => {
        properties => {
            foo => { type => 'integer' },
            bar => { type => 'object' },
        },
});

ok $schema->check({ foo => 1, bar => { two => 2 } }), "valid check";
ok !$schema->check({ foo => 'potato', bar => { two => 2 } }), "invalid check";

subtest '2019-09' => sub {
    ok( JSON::Schema::AsType->new(
        draft => '2019-09', schema => {}
    ), 'can create a 2019-09 schema' );
};

done_testing;

