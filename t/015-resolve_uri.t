use 5.42.0;

use Test2::V1 -Pip;

use experimental qw/ refaliasing /;

use JSON::Schema::AsType::Registry;

*resolve_uri = *JSON::Schema::AsType::Registry::_resolve_uri;

my @cases = (
	[ ['http://foo.com/bar'], 'http://foo.com/bar', "just the url" ],
	[ ['http://foo.com/bar','http://other.com'], 'http://foo.com/bar', "absolute" ],
	[ ['/bar','http://other.com'], 'http://other.com/bar', "relative" ],
	[ ['#/this/that','http://other.com'], 'http://other.com/#/this/that' ],
	[ ['#/this/that','http://other.com/#/elsewhere'], 'http://other.com/#/this/that'],
	[ ['#./this/that','http://other.com/#/elsewhere'],
	'http://other.com/#/elsewhere/this/that', 'relative fragment'],
 [ [ 'node' , 'http://localhost:1234/tree#/properties/nodes/items'] => 
 	'http://localhost:1234/node' ]
);

is resolve_uri( $_->[0]->@* ) => $_->[1], $_->[2] // join ' + ', $_->[0]->@*
	for @cases;

done_testing;
