package JSON::Schema::AsType::Draft3::Types;
# ABSTRACT: JSON-schema v3 keywords as types

=head1  SYNOPSIS

    use JSON::Schema::AsType::Draft3::Types '-all';

    my $type = Object & 
        Properties[
            foo => Minimum[3]
        ];

    $type->check({ foo => 5 });  # => 1
    $type->check({ foo => 1 });  # => 0

=head1 EXPORTED TYPES

        Null Boolean Array Object String Integer Pattern Number Enum

        OneOf AllOf AnyOf 

        Not

        Minimum ExclusiveMinimum Maximum ExclusiveMaximum MultipleOf

        MaxLength MinLength

        Items AdditionalItems MaxItems MinItems UniqueItems

        PatternProperties AdditionalProperties MaxProperties MinProperties

        Dependencies Dependency

=cut

use strict;
use warnings;

use Type::Utils -all;
use Types::Standard qw/ 
    Str StrictNum HashRef ArrayRef 
    Int
    Dict slurpy Optional Any
    Tuple
/;

use Type::Library
    -base,
    -declare => qw(
        Disallow
        Extends
        DivisibleBy
    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON qw/ to_json from_json /;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft4::Types 'Not', 'Integer', 'MultipleOf',
    'Boolean', 'Number', 'String';

__PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String;

declare Disallow => 
    constraint_generator => sub {
        Not[ shift ];
    };

declare Extends => 
    constraint_generator => sub {
        reduce { $a & $b } @_;
    };

declare DivisibleBy =>
    constraint_generator => sub {
        MultipleOf[shift];
    };


1;
