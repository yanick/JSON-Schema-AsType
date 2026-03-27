package JSON::Schema::AsType::Draft2020_12::Vocabulary::Validation;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature         qw/ module_true signatures /;
use Types::Standard qw/Any /;
use List::Util      qw/ pairmap /;

use Moose::Role;

use JSON::Schema::AsType::Draft4::Types qw/ Boolean /;
use JSON::Schema::AsType::Draft2019_09::Types qw/ /;
use JSON::Schema::AsType::Draft2020_12::Types qw/ PrefixItems Items /;

use JSON::Schema::AsType::Draft6::Keywords;

with 'JSON::Schema::AsType::Draft2019_09::Vocabulary::Validation' => { -excludes => [ '_keyword_items' ] };

