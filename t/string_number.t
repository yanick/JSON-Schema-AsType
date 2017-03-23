use strict;
use warnings;

use Test::More tests => 4;

use JSON::Schema::AsType;


for ( 3,4 ) {
    local $JSON::Schema::AsType::strict_string = 1;
    ok( !JSON::Schema::AsType->new(
        draft_version => $_,
        schema => { type => 'string' },
    )->check( "123" ), "v$_" );
}

for ( 3,4 ) {
    local $JSON::Schema::AsType::strict_string = 0;
    ok( JSON::Schema::AsType->new(
        draft_version => $_,
        schema => { type => 'string' },
    )->check( "123" ), "v$_" );
}
