package JSON::Schema::AsType::Draft2019_09::Types;
# ABSTRACT: JSON-schema v2019-09 keywords as types

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

use 5.42.0;
use warnings;

use feature qw/ signatures /;

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
		DependantRequired
    );

use List::MoreUtils qw/ all any zip none /;
use List::Util qw/ pairs pairmap reduce uniq /;

use JSON::Schema::AsType;


# __PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String, Null, Object, Array, Items, ExclusiveMaximum, ExclusiveMinimum;

declare DependentRequired => 
    constraint_generator => sub($depends) {
		return sub {
			# only for objects
			return 1 unless ref eq 'HASH';

			for my ($prop, $deps ) (%$depends)  {
				next unless exists $_->{$prop};
				for my $d (@$deps) {
					return 0 unless exists $_->{$d};
				}
			}
			return 1;
		}
    };

declare Schema, as InstanceOf['Type::Tiny'];

coerce Schema,
    from HashRef,
    via { 
        my $schema = JSON::Schema::AsType->new( draft => '2019-09', schema => $_ );

        if ( $schema->validate_schema ) {
            die "not a valid Draft2019_09 json schema\n";
        }

        $schema->type 
    };

1;


