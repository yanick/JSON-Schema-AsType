package JSON::Schema::AsType;

# ABSTRACT: generates Type::Tiny types out of JSON schemas

use 5.14.0;

use feature 'signatures';

use strict;
use warnings;

use PerlX::Maybe;
use Type::Tiny;
use Type::Tiny::Class;
use Scalar::Util    qw/ looks_like_number /;
use List::Util      qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard
  qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int Object slurpy Dict Optional slurpy /;
use Type::Utils;
use Clone 'clone';
use URI;
use Module::Runtime qw/ use_module /;

use Moose::Util qw/ apply_all_roles /;
use JSON::Schema::AsType::Registry;

use JSON;

use Moose;

use MooseX::MungeHas 'is_ro';

no warnings 'uninitialized';

our $strict_string = 1;

with 'JSON::Schema::AsType::Registry';

has type => (
	is      => 'rwp',
	handles => [qw/ check validate validate_explain /],
	builder => 1,
	lazy    => 1
);

has draft_version => (
	is      => 'ro',
	lazy    => 1,
	default => sub {
		$_[0]->has_specification
		  ? $_[0]->specification =~ /(\d+)/ && $1
		  : eval { $_[0]->parent_schema->draft_version } || 4;
	},
	isa => enum( [ 3, 4, 6 ] ),
);

has spec => (
	is      => 'ro',
	lazy    => 1,
	default => sub {
		$_[0]->fetch( sprintf "https://json-schema.org/draft-%02d/schema",
			$_[0]->draft_version );
	},
);

has schema => (
	predicate => 'has_schema',
	is => 'ro',
	lazy      => 1,
	default   => sub {
		return +{};
		my $self = shift;

		my $uri = $self->uri or die "schema or uri required";

		return $self->fetch($uri)->schema;
	},
);

sub _schema_trigger {}

has parent_schema => ( clearer => 1, );

has strict_string => (
	is      => 'ro',
	lazy    => 1,
	default => sub {
		my $self = shift;

		$self->parent_schema->strict_string if $self->parent_schema;

		return $JSON::Schema::AsType::strict_string;
	},
);

has uri => (
	is      => 'ro',
	trigger => sub {
		my ( $self, $uri ) = @_;
		$uri = URI->new($uri);
		return if $uri->fragment;
		$self->clear_parent_schema;
	}
);

has references => sub {
	+{};
};

has specification => (
	predicate => 1,
	is        => 'ro',
	lazy      => 1,
	default   => sub {
		return 'draft' . $_[0]->draft_version;
		eval { $_[0]->parent_schema->specification } || 'draft4';
	},
	isa => enum 'JsonSchemaSpecification',
	[qw/ draft3 draft4 draft6 /],
);

sub specification_schema {
	my $self = shift;

	$self->spec->schema;
}

sub validate_schema {
	my $self = shift;
	$self->spec->validate( $self->schema );
}

sub validate_explain_schema {
	my $self = shift;
	$self->spec->validate_explain( $self->schema );
}

sub root_schema {
	my $self = shift;
	eval { $self->parent_schema->root_schema } || $self;
}

sub is_root_schema {
	my $self = shift;
	return not $self->parent_schema;
}

sub sub_schema($self,$subschema,$uri) {

	$uri = $self->resolve_uri($uri) if $uri;


	$self->new( schema => $subschema, parent_schema => $self, registry => $self->registry, maybe uri => $uri );
}

sub absolute_id {
	my ( $self, $new_id ) = @_;

	return $new_id if $new_id =~ m#://#;    # looks absolute to me

	my $base = $self->ancestor_uri;

	$base =~ s#[^/]+$##;

	return $base . $new_id;
}

sub _build_type {
	my $self = shift;

	$self->_set_type('');

	# $ref trumps all
	return $self->_process_keyword('$ref')
	  if $self->schema->{'$ref'};

	my @types =
	  grep { $_ and $_->name ne 'Any' }
	  map { $self->_process_keyword($_) } $self->all_keywords;

	return @types ? reduce { $a & $b } @types : Any;
}

sub all_keywords {
	my $self = shift;

	# 'id' has to be first
	return sort { $a eq 'id' ? -1 : $b eq 'id' ? 1 : $a cmp $b }
	  map { /^_keyword_(.*)/ } $self->meta->get_method_list;
}

sub _process_keyword {
	my ( $self, $keyword ) = @_;

	return unless exists $self->schema->{$keyword};

	my $value = $self->schema->{$keyword};

	my $method = "_keyword_$keyword";

	$self->$method($value);
}

# returns the first defined parent uri
sub ancestor_uri {
	my $self = shift;

	return $self->uri || eval { $self->parent_schema->ancestor_uri };
}

sub resolve_reference {
	my ( $self, $ref ) = @_;

	my $uri = $self->resolve_uri($ref);

	my $schema = $self->fetch($uri) or die "couldn't retrieve schema $uri\n";

	return $schema;
}

sub _unescape_ref {
	my ( $self, $ref ) = @_;

	$ref =~ s/~0/~/g;
	$ref =~ s!~1!/!g;
	$ref =~ s!%25!%!g;

	$ref;
}

sub _escape_ref {
	my ( $self, $ref ) = @_;

	$ref =~ s/~/~0/g;
	$ref =~ s!/!~1!g;
	$ref =~ s!%!%25!g;

	$ref;
}

sub _add_reference {
	my ( $self, $path, $schema ) = @_;

	$path = join '/', '#', map { $self->_escape_ref($_) } @$path
	  if ref $path;

	$self->references->{$path} = $schema;
}

sub _add_to_type {
	my ( $self, $t ) = @_;

	if ( my $already = $self->type ) {
		$t = $already & $t;
	}

	$self->_set_type($t);
}

sub BUILD {
	my $self = shift;

	use_module(
		'JSON::Schema::AsType::' . ucfirst( $self->specification )
	)->meta->rebless_instance( $self );

	# make it available early for the potential $refs
	$self->register_schema( $self->uri, $self ) if $self->uri;

	# TODO move the role into a trait, which should take care of this
	$self->_schema_trigger($self->schema) if $self->has_schema;
	$self->type if $self->has_schema;

}

1;
