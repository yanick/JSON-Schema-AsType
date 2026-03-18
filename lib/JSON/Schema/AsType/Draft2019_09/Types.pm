package JSON::Schema::AsType::Draft2019_09::Types;
# ABSTRACT: JSON-schema v6 keywords as types

=head1  SYNOPSIS

    use JSON::Schema::AsType::Draft6::Types '-all';

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

=head2 Schema

Only verifies that the variable is a L<Type::Tiny>. 

Can coerce the value from a hashref defining the schema.

    my $schema = Schema->coerce( \%schema );

    # equivalent to

    $schema = JSON::Schema::AsType::Draft4->new(
        draft => 6,
        schema => \%schema;
    )->type;

=cut

use strict;
use warnings;

use Type::Utils -all;
use Types::Standard qw/ 
    Str StrictNum HashRef ArrayRef 
    Int
    Dict slurpy Optional Any
    Tuple
    InstanceOf
/;

use Type::Library
    -base,
    -declare => qw(
        MaxContains
        MinContains
    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft4::Types qw/
    Integer Boolean Number String Null Object Array Items
    ExclusiveMinimum ExclusiveMaximum Dependencies Dependency
    Not MultipleOf
/;

#__PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String, Null, Object, Array, Items, ExclusiveMaximum, ExclusiveMinimum;

declare MaxContains,
    constraint_generator => sub{
        my $nbr = shift;

        return sub {
            return $JSON::Schema::AsType::CONTEXT{contains}->@* <= $nbr;
        }
    };

declare MinContains,
    constraint_generator => sub{
        my $nbr = shift;

        return sub {
            $DB::single = 1;
            return $JSON::Schema::AsType::CONTEXT{contains}->@* >= $nbr;
        }
    };
