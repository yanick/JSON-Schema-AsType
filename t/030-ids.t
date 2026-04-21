use 5.42.0;
use warnings;

use Test2::V1 -Pip;
use Test2::Tools::Exception qw/lives/;

use feature qw/ signatures/;

use JSON::Schema::AsType;
use JSON;

ok lives {
my $schema = JSON::Schema::AsType->new(
    draft  => '2019-09',
 schema => {
            '$defs'=> {
                'id_in_enum'=> {
                    'enum'=> [
                        {
                          '$id'=> 'https://localhost:1234/draft2019-09/id/my_identifier.json',
                          'type'=> 'null'
                        }
                    ]
                },
                'real_id_in_schema'=> {
                    '$id'=> 'https://localhost:1234/draft2019-09/id/my_identifier.json',
                    'type'=> 'string'
                },
                'zzz_id_in_const'=> {
                    'const'=> {
                        '$id'=> 'https://localhost:1234/draft2019-09/id/my_identifier.json',
                        'type'=> 'null'
                    }
                }
            },
            'anyOf'=> [
                { '$ref'=> '#/$defs/id_in_enum' },
                { '$ref'=> 'https://localhost:1234/draft2019-09/id/my_identifier.json' }
            ]
        }   
);

$schema->type;
}, 'it compiles';

done_testing;
