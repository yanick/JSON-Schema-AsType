package JSON::Schema::AsType::Draft7::Types;
# ABSTRACT: JSON-schema v7 keywords as types

=head1  SYNOPSIS

    use JSON::Schema::AsType::Draft6::Types '-all';

    my $type = Object & 
        Properties[
            foo => Minimum[3]
        ];

    $type->check({ foo => 5 });  # => 1
    $type->check({ foo => 1 });  # => 0

=head1 EXPORTED TYPES


=head2 Schema

Only verifies that the variable is a L<Type::Tiny>. 

Can coerce the value from a hashref defining the schema.

    my $schema = Schema->coerce( \%schema );

    # equivalent to

    $schema = JSON::Schema::AsType::Draft4->new(
        draft => 7,
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
        Schema
    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON::Schema::AsType;


# __PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String, Null, Object, Array, Items, ExclusiveMaximum, ExclusiveMinimum;

declare If => 
    constraint_generator => sub {
		my($if,$then,$else) = @_;

		return sub {
			$if->check($_) ?$then->check($_):$else->check($_);
		}


    };

declare Schema, as InstanceOf['Type::Tiny'];

coerce Schema,
    from HashRef,
    via { 
        my $schema = JSON::Schema::AsType->new( draft => 7, schema => $_ );

        if ( $schema->validate_schema ) {
            die "not a valid draft7 json schema\n";
        }

        $schema->type 
    };

1;


