package JSON::Schema::AsType::Draft2019_09::Vocabulary::Applicator;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature qw/ module_true /;

use Moose::Role;

with 'JSON::Schema::AsType::Draft7::Keywords' =>
  { -excludes => [ map { "_keyword_$_" } qw/ minimum /,
   '$id',
   '$ref',
  # "properties",
  # "items",
  # "patternProperties",
  # "additionalProperties",
  # "additionalItems",
  # "allOf",
  # "anyOf",
  # "oneOf",
 # "if",
 "multipleOf",
 "uniqueItems",
 "minItems",
 "exclusiveMaximum",
 # "const",
 # "dependencies",
 "exclusiveMinimum",
 "maxProperties",
 "minLength",
 "pattern",
 # "enum",
 # "definitions",
 # "required",
 "contains",
 "maximum",
 "maxItems",
  "propertyNames",
  "minProperties",
  "maxLength",
 # "type",
 # "not" 
	 ] };
