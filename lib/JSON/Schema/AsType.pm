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

use JSON;
use Type::Utils qw( class_type );

use Moose;
use MooseX::MungeHas 'is_ro';

with 'JSON::Schema::AsType::Registry';
with 'JSON::Schema::AsType::Type';

no warnings 'uninitialized';

our $strict_string = 1;

our @DRAFT_VERSIONS = ( 3, 4, 6, 7, '2019-09' );

has draft => (
    is      => 'ro',
    lazy    => 1,
    default => sub($self) {
        return $self->parent_schema->draft if $self->parent_schema;
        return $DRAFT_VERSIONS[-1];
    },
    isa => enum( \@DRAFT_VERSIONS ),
);

has metaschema => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        $_[0]->fetch( sprintf "https://json-schema.org/draft-%02d/schema",
            $_[0]->draft );
    },
);

has schema => (
    predicate => 'has_schema',
    is        => 'ro',
    lazy      => 1,
    default   => sub {
        return +{};
        my $self = shift;

        my $uri = $self->uri or die "schema or uri required";

        return $self->fetch($uri)->schema;
    },
);

sub _schema_trigger { }

has parent_schema => ( clearer => 1, );

has strict_string => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;

        return $self->parent_schema->strict_string if $self->parent_schema;

        return $JSON::Schema::AsType::strict_string;
    },
);

has uri => (
    is  => 'ro',
    isa => class_type( { class => 'URI' } )->plus_constructors( Str, "new", ),
    coerce  => 1,
    trigger => sub {
        my ( $self, $uri ) = @_;
        return if $uri->fragment;
    }
);

# for 2019-09 and up
has scoped => (
	is => 'ro',
	default => 1,
);

sub sub_schema( $self, $subschema, $uri, $scoped = 1 ) {

    $uri = $self->resolve_uri($uri) if $uri;

    JSON::Schema::AsType->new(
        draft         => $self->draft,
        schema        => $subschema,
        parent_schema => $self,
        registry      => $self->registry,
		scoped 		  => $scoped,
        maybe uri     => $uri
    );

}

sub all_active_keywords($self) {
    return grep { exists $self->schema->{$_} } $self->all_keywords;
}

sub all_keywords {
    my $self = shift;

    # 'id' has to be first
    return sort { $a eq 'id' ? -1 : $b eq 'id' ? 1 : $a cmp $b }
      map { /^_keyword_(.*)/ } $self->meta->get_method_list;
}

sub has_keyword( $self, $keyword ) {
    my $method = "_keyword_$keyword";
    return $self->can($method);
}

sub _process_keyword {
    my ( $self, $keyword ) = @_;

    my $value = $self->schema->{$keyword};

    my $method = "_keyword_$keyword";

    $self->$method($value);
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
    $ref =~ s!%22!"!g;

    $ref;
}

sub _escape_ref {
    my ( $self, $ref ) = @_;

    $ref =~ s/~/~0/g;
    $ref =~ s!/!~1!g;
    $ref =~ s!%!%25!g;
    $ref =~ s!"!%22!g;

    $ref;
}

sub BUILD {
    my $self = shift;

    use_module( 'JSON::Schema::AsType::Draft' . $self->draft =~ s/-/_/r )
      ->meta->rebless_instance($self);

    # make it available early for the potential $refs
    $self->register_schema( $self->uri, $self ) if $self->uri;

    # TODO move the role into a trait, which should take care of this
    $self->_schema_trigger( $self->schema ) if $self->has_schema;

    $self->_after_build if $self->can('_after_build');

}

1;
