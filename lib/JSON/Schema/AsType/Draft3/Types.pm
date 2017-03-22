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

        Properties

        Dependencies Dependency
    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON qw/ to_json from_json /;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft4::Types 'Not', 'Integer', 'MultipleOf',
    'Boolean', 'Number', 'String', 'Null', 'Object', 'Array';

__PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String, Null, Object, Array;

declare Dependencies,
    constraint_generator => sub {
        my %deps = @_;

        return reduce { $a & $b } pairmap { Dependency[$a => $b] } %deps;
    };

declare Dependency,
    constraint_generator => sub {
        my( $property, $dep) = @_;

        sub {
            return 1 unless Object->check($_);
            return 1 unless exists $_->{$property};

            my $obj = $_;

            return all { exists $obj->{$_} } @$dep if ref $dep eq 'ARRAY';
            return exists $obj->{$dep} unless ref $dep;

            return $dep->check($_);
        }
    };

declare Properties =>
    constraint_generator => sub {
        my $type = Dict[@_, slurpy Any];

        sub {
            ! Object->check($_) or $type->check($_)
        }
    };

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
