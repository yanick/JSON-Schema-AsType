use 5.10.0;

use strict;
use warnings;

use Test::More;

use JSON;

use JSON::Schema::AsType::Draft4::Types '-all';

test_type( Minimum[5], [ 6, 'banana', 5 ], [ 4 ] );
test_type( ExclusiveMinimum[5], [ 6, 'banana' ], [ 5, 4 ] );

test_type( Maximum[5], [ 4, 'banana', 5 ], [ 6 ] );
test_type( ExclusiveMaximum[5], [ 4, 'banana' ], [ 5, 6 ] );

test_type( MinLength[5], [ 6, 'banana', {} ], [ 'foo' ] );

test_type( MultipleOf[5], [ 10, 'banana' ], [ 3 ] );

test_type( MaxItems[2], [ 10, [1] ], [ [1..3] ] );
test_type( MinItems[2], [ 10, [1..2] ], [ [1] ] );

test_type( Null, [ undef ], [ 'banana' ] );

test_type( Boolean, [ JSON::true, JSON::false ], [ 1 ] );

done_testing;

sub test_type {
    my( $type, $good, $bad ) = @_;

    subtest $type => sub {

        subtest 'valid values' => sub {
            for my $test ( @$good ) {
                ok $type->check($test), join '', 'value: ', explain $test;
            }
        } if $good;

        subtest 'bad values' => sub {
            my $printed = 0;
            for my $test ( @$bad ) {
                my $error = $type->validate($test);
                ok $error, join '', 'value: ', explain $test;
                diag $error unless $printed++;
            }
        } if $bad;
    };

}
