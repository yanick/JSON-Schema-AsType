package JSON::Schema::AsType::Draft2020_12::Vocabulary::Validation;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature         qw/ module_true signatures /;
use Types::Standard qw/Any ArrayRef /;
use List::Util      qw/ pairmap /;

use Moose::Role;

use JSON::Schema::AsType::Visit;
use JSON::Schema::AsType::Draft4::Types qw/ Boolean /;
use JSON::Schema::AsType::Draft2019_09::Types qw/ /;
use JSON::Schema::AsType::Draft2020_12::Types qw/ MinContains MaxContains /;

use JSON::Schema::AsType::Annotations;
use JSON::Schema::AsType::Draft6::Keywords;

with 'JSON::Schema::AsType::Draft2019_09::Vocabulary::Validation' => { -excludes => [ map { "_keyword_$_" } qw/items contains/] };


sub _keyword_minContains($self,$min) {
	return Any unless $self->schema->{contains};
	return ~ArrayRef | MinContains[$min];
}

sub _keyword_maxContains($self,$min) {
	return Any unless $self->schema->{contains};
	return ~ArrayRef | MaxContains[$min];
}

sub _find_dynamicAnchor($self,$ref) {

	my $anchor;

	JSON::Schema::AsType::Visit::visit(
		$self->schema,
		sub {
			my ( $key, $valueref, $context ) = @_;

			return if $anchor;

			no warnings qw/ uninitialized /;

			my $verdict = (ref($_) eq 'HASH') &&( ($_->{'$dynamicAnchor'} eq $ref)or( $ref eq $_->{'$anchor'}));

			$anchor = $self->sub_schema( $_, join '/', '#', $context->{_path}->@* ) if $verdict;

		}
	);
	return $anchor;

}

__PACKAGE__->meta->add_method(
	'_keyword_$dynamicRef' => sub {
		my ( $self, $ref ) = @_;

		my $schema;

		return Type::Tiny->new(
			display_name => "DynamicRef($ref)",
			constraint   => sub {

				my $v = $_;

				my $anchor;
				my $parent = $self;

				my $first_id;

				$DB::single = 1;

				$ref =~ s/^#//;
				
				$DB::single = 1;

				while ( $parent = $parent->parent_schema ) {

					$anchor = $parent->_find_dynamicAnchor($ref) and last;

				}

				die "anchor not found\n" unless $anchor;

				# use DDP; p $anchor->schema;
				# warn "checking for $v\n";
				return $anchor->base_type->check($v);
			},
		);
	}
);
