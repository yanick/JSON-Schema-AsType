package JSON::Schema::AsType::Draft7::Keywords;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use strict;
use warnings;

use Moose::Role;

use Type::Utils;
use Scalar::Util    qw/ looks_like_number /;
use List::Util      qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard
  qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int slurpy Dict Optional slurpy /;

use JSON;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft6::Types '-all';

use JSON::Schema::AsType::Draft7::Types qw/ If /;

with 'JSON::Schema::AsType::Draft6::Keywords';

sub _keyword_if {
    my ( $self, $if ) = @_;

    $if = $self->sub_schema( $if, '#./if' )->base_type;

    my @clauses = map {
        defined $self->schema->{$_}
          ? $self->sub_schema( $self->schema->{$_}, "#./$_" )->base_type
          : Any
    } qw/ then else/;

    return If [ $if, @clauses ];

}

1;
