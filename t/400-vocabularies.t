
use Test2::V1 -Pip;

use Moose::Util qw/ does_role /;

use JSON::Schema::AsType::Draft2019_09;

my $schema = JSON::Schema::AsType::Draft2019_09->new( schema => {} );

my @vocabularies = $schema->vocabularies->@*;

is scalar @vocabularies => 5, "2019-09 has 5 default vocabs";

ok does_role($schema, $_), "does $_" for map { "JSON::Schema::AsType::Draft2019_09::Vocabulary::$_"} qw/ 
   Core 
   Applicator 
   Validation 
   Metadata
   Content
/;

done_testing;
