package JSON::Schema::AsType::Draft2020_12::Types;

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

use 5.42.0;
use warnings;

use feature qw/ module_true /;

use Hash::Merge qw/ merge /;
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
  PrefixItems
  Contains
  );

use List::MoreUtils qw/ zip none any all /;
use List::Util      qw/ pairs pairmap reduce uniq /;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft4::Types qw/
  Integer Boolean Number String Null Object Array Items
  ExclusiveMinimum ExclusiveMaximum Dependencies Dependency
  Not MultipleOf
  /;

#__PACKAGE__->meta->add_type( $_ ) for Integer, Boolean, Number, String, Null, Object, Array, Items, ExclusiveMaximum, ExclusiveMinimum;

declare PrefixItems,
  constraint_generator => sub {
	my $types = shift;

	if ( Boolean->check($types) ) {
		return $types ? Any : sub { !@$_ };
	}

	my $type =
	  ref $types eq 'ARRAY'
	  ? Tuple [ ( map { Optional [$_] } @$types ), slurpy Any ]
	  : Tuple [ slurpy ArrayRef [$types] ];

	return ~ArrayRef | (
		$type & sub {
			if ( ref $types eq 'ARRAY' ) {
				push $JSON::Schema::AsType::SCOPE{prefixItems}->@*,
				  0 .. $types->$#*;
			}
			else {
				push $JSON::Schema::AsType::SCOPE{prefixItems}->@*,
				  0 .. $_->$#*;
			}
			return 1;
		}
	);

  };

declare Contains,
  constraint_generator => sub($type) {
	  return sub { 
		  return any { $type->check($_) } @$_ }
  };

declare Items, constraint_generator => sub {
	if ( @_ > 1 ) {
		my $to_skip = shift;
		my $schema  = shift;
		return sub {

			return unless ref eq 'ARRAY';

			my @v = @$_;

			my @additional = splice @v, $to_skip;

			if ( ref $schema eq 'JSON::PP::Boolean' ) {
				my $verdict = @additional;
				$verdict = !$verdict unless $schema;
				return $verdict;
			}

			return all { $schema->check($_) } @additional;
		}
	}
	else {
		my $size = shift;
		if ( ref $size eq 'JSON::PP::Boolean' ) {
			return sub {
				my $s = ref($_) eq 'ARRAY' ? @_ : 0;
				$DB::single = 1;
				return !!$size ? $s : !$s;
			}
		}
		return sub {
			my $s = ref($_) eq 'ARRAY' ? @_ : 0;
			$s <= $size;
		};
	}
};
