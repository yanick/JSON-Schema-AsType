package JSON::Schema::AsType::Registry;

use 5.42.0;

use feature 'signatures';

use strict;
use warnings;

use Test::Deep::NoTest qw/ eq_deeply /;
use JSON::Pointer;
use JSON;
use LWP::Simple     qw//;
use Module::Runtime qw/ use_module /;

use Moose::Role;

has registry => (
	is      => 'ro',
	lazy    => 1,
	default => sub { +{} },
	traits  => ['Hash'],
	handles => {
		all_schema_uris => 'keys',
		register_schema => 'set',
	},
);

around register_schema => sub {

	# TODO Use a type instead to coerce into canonical
	my ( $orig, $self, $uri, $schema ) = @_;

	$uri = URI->new($uri)->canonical;

	#warn "registering $uri with "; use DDP; p $schema->schema;
	
	my $fragment = $uri->fragment;
	warn $fragment;


	if ( my $already =  $self->registered_schema($uri) ) {
		my $s = $schema;
		$s = $s->schema if $s isa JSON::Schema::AsType;
		return if eq_deeply( $s, $already->schema );
		use DDP;
		p $s;
		p $already->schema;
		die "schema $uri already registered\n";
	}

	unless ( $schema isa JSON::Schema::AsType ) {
		$schema = JSON::Schema::AsType->new(
			schema   => $schema,
			registry => $self->registry
		);
	}

	$orig->( $self, $uri, $schema );
};

sub registered_schema( $self, $uri ) {
	$uri = URI->new($uri)->canonical;
	return $self->registry->{$uri};
}

sub fetch {
	my ( $self, $url ) = @_;

	# # is it one of the spec schemas?
	# if ( $url =~ qr[^https?://json-schema.org/draft-0?(\d+)/schema] ) {

	# 	# TODO get the metaschema
	# 	my $module = 'JSON::Schema::AsType::Draft' . $1;
	# 	use_module($module)->metaschema;
	# }

	$url = $self->resolve_uri( $url, $self->root_schema->uri );

	if ( my $schema = $self->registered_schema($url) ) {
		return $schema;
	}

	my $root_uri = $url->clone;
	$root_uri->fragment(undef);

	my $schema = $self->registered_schema($root_uri);

	if ($schema) {
			my $fragment = $url->fragment;
			$fragment =~ s#/$##;
		my $s= JSON::Pointer->get( $schema->schema, $fragment );
		unless($s) {
			die "reference #" . $fragment . ' not found';
		}
		return $self->register_schema( $url => $s);
	}
	warn $schema;

	die "sadness";

	# my $schema = eval { from_json LWP::Simple::get($url) };

	# die "couldn't get schema from '$url'\n" unless ref $schema eq 'HASH';

	# return $self->register_schema(
	# 	$url => $self->new( uri => $url, schema => $schema ) );
}

sub resolve_uri( $self, $uri, $base = undef ) {
	return _resolve_uri( $uri, $base // $self->uri );
}

around resolve_uri => sub ($orig, $self, $uri, $base = undef ) {
	my $result = $orig->($self,$uri,$base);
	$base //= $self->uri;
	warn "==> $uri + $base = $result\n";
	return $result;
};

sub _resolve_uri {
	my ( $uri, $base ) = @_;
	$uri = URI->new($uri);
	$base = URI->new($base);

	return $uri unless $base;

	my $result = URI->new($uri)->abs($base)->canonical;

	# let's look at those fragments
	my $uri_doc = $uri->clone;
	$uri_doc->fragment(undef);
	my $base_doc = $base->clone;
	$base_doc->fragment(undef);

	if ( !"$uri_doc" or $uri_doc->eq($base_doc) ) {
		no warnings qw/ uninitialized /;
		my $fragment      = $uri->fragment;
		my $base_fragment = $base->fragment;
		$base_fragment .= '/' unless m[/$];

		my $path = URI->new($fragment);
		$path = $path->abs($base_fragment) if $base_fragment;
		$path = $path->canonical;

		$result->fragment($path) unless $path eq '/';
	} else {
		# not the same documents? fragment stays the same
		no warnings 'uninitialized';
		$result->fragment($uri->fragment||undef);
	}

	return $result;

}
