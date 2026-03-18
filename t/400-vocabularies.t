
use Test2::V1 -Pip;

use Moose::Util qw/ does_role /;

use JSON::Schema::AsType::Draft2019_09;

my $schema = JSON::Schema::AsType::Draft2019_09->new( schema => { const => 2 } );

my @vocabularies = $schema->vocabularies->@*;

is scalar @vocabularies => 5, "2019-09 has 5 default vocabs";

subtest 'has the vocab roles' => sub {
    $schema->type; # needs to trigger the role assignment

    ok does_role($schema, $_), "does $_" for map { "JSON::Schema::AsType::Draft2019_09::Vocabulary::$_"} qw/ 
    Core 
    Applicator 
    Validation 
    Metadata
    Content
    /;
};

ok $schema->has_keyword('const'), 'has the method for const';

ok !$schema->check('potato'), 'validation fails, as it should';

print join "\n", $schema->all_keywords;

done_testing;
