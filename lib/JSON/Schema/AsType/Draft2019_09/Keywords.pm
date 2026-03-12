package JSON::Schema::AsType::Draft2019_09::Keywords;
# ABSTRACT: Role processing draft2019-09 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use strict;
use warnings;

use feature qw/ module_true /;

use Moose::Role;

use Type::Utils;
use Scalar::Util qw/ looks_like_number /;
use List::Util qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int slurpy Dict Optional slurpy /; 

use JSON;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft2019_09::Types qw/ DependentRequired /;

with 'JSON::Schema::AsType::Draft7::Keywords';

override all_keywords => sub {
    my $self = shift;
    
    return uniq '$id', super();
};

sub _keyword_dependentRequired {
	my( $self, $depends) = @_;

	DependentRequired[$depends];
}
