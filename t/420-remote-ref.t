use Test2::V1 -Pip;

use JSON::Schema::AsType;
use JSON;

my $schema = JSON::Schema::AsType->new(
    draft  => '2019-09',
    schema => {
            '$schema'=> "https://json-schema.org/draft/2019-09/schema",
            '$ref'=> "https://json-schema.org/draft/2019-09/schema"
    }
);

ok $schema->check({minLength => 1 });


done_testing;
