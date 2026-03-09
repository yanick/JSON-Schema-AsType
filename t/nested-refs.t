use 5.42.0;

use Test2::V1 -Pip;

use JSON::Schema::AsType;

my $schema = JSON::Schema::AsType->new(
    strict_string => 0,
    schema => {
            "definitions"=> {
                "a"=> {"type"=> "integer"},
                "b"=> {'$ref'=> "#/definitions/a"},
                "c"=> {'$ref'=> "#/definitions/b"}
            },
            '$ref' => "#/definitions/a"
    }
);

say "=== will check now===";

say join "\n", $schema->all_schema_uris;
ok $schema->check(2) for 1..2;
done_testing;
# diag join "\n", $schema->validate_explain(1)->@*;
