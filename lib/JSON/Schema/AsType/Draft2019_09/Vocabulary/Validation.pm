package JSON::Schema::AsType::Draft2019_09::Vocabulary::Validation;
# ABSTRACT: Role processing draft7 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature qw/ module_true /;
use Types::Standard qw/Any/;
use List::Util qw/ pairmap /;

use Moose::Role;

use JSON::Schema::AsType::Draft2019_09::Types qw/ 
	DependentRequired 
	DependentSchemas
/;

with 'JSON::Schema::AsType::Draft7::Keywords' => {
	-exclude => [ ]
};

__PACKAGE__->meta->add_method(
	'_keyword_$recursiveRef' => sub {
		my ( $self, $ref ) = @_;

		my $schema;

		return Type::Tiny->new(
			name         => 'RecursiveRef',
			display_name => "RecursiveRef($ref)",
			constraint   => sub {

				my $v = $_;

				my $parent = $self;
				$DB::single = 1;
				while($parent = $parent->parent_schema ) {
					return $parent->check($v) if $parent->schema->{'$recursiveAnchor'};
				}

				local $::DEEP = ( $::DEEP // 0 ) + 1;
				die if $::DEEP > 10;
				use JSON::Schema::AsType::Debug;
				debug( 'in ref for %s', $ref );
				$schema //= $self->resolve_reference($ref);

				my $result = $schema->check($v) || 0;

				return $result;
			},
			message => sub {
				join "\n",
				  "ref schema is "
				  . to_json( $schema->schema, { allow_nonref => 1 } ),
				  @{ $schema->validate_explain($_) };
			}
		);
	}
);

sub _keyword_dependentRequired {
	my( $self, $depends) = @_;

	DependentRequired[$depends];
}

sub _keyword_dependentSchemas {
	my( $self, $depends) = @_;

	my %depends = pairmap {
		$a => $self->sub_schema($b, "#./dependentSchema/$a")
	} %$depends;

	DependentSchemas[\%depends];
}
