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

	if ( my $already =  $self->registered_schema($uri) ) {
		my $s = $schema;
		$s = $s->schema if $s isa JSON::Schema::AsType;
		return $already if eq_deeply( $s, $already->schema );
		use DDP;
		p $s;
		p $already->schema;
		die "schema $uri already registered\n";
	}

	debug("registering %s",$uri);
	unless ( $schema isa JSON::Schema::AsType ) {
		$schema = JSON::Schema::AsType->new(
			uri => $uri,
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

	debug("fetching %s", $url);
	$DB::single = 1;
	# # is it one of the spec schemas?
	# if ( $url =~ qr[^https?://json-schema.org/draft-0?(\d+)/schema] ) {

	# 	# TODO get the metaschema
	# 	my $module = 'JSON::Schema::AsType::Draft' . $1
	# 	use_module($module)->metaschema;
	# }

	$url = $self->resolve_uri( $url, $self->root_schema->uri );

	# urgh...
	$url->scheme("https") if $url->host eq 'json-schema.org';

	my $fragment = $url->fragment;
	$url->fragment( $fragment =~ s[/+$][]r ) if $fragment;

	if ( my $schema = $self->registered_schema($url) ) {
		return $schema;
	}

	my $root_uri = $url->clone;
	$root_uri->fragment(undef);

	my $schema = $self->registered_schema($root_uri);
	use JSON::Schema::AsType::Debug;
	debug( "got the root schema for $root_uri and it's %s", !!$schema);

	if ($schema) {
			my $fragment = $url->fragment;
			$fragment =~ s#/+$##;
			$url->fragment($fragment);
		my $s= JSON::Pointer->get( $schema->schema, $fragment );
		unless($s) {
			die "reference #" . $fragment . ' not found';
		}
		debug( "registering for $url?");
		my $x = $self->register_schema( $url => $s);
		warn $x;
		return $x;
	}

	if( $root_uri->host eq 'json-schema.org' and $root_uri->path =~ m#/draft-0?(\d+)# ) {
	 	my $module = 'JSON::Schema::AsType::Draft' . $1;
	 	my $ms = use_module($module)->metaschema;
		$self->register_schema( $ms->uri => $ms );
		goto __SUB__;
	}
	debug( $self->all_schema_uris );
	debug($root_uri);

	die "sadness";

	# my $schema = eval { from_json LWP::Simple::get($url) };

	# die "couldn't get schema from '$url'\n" unless ref $schema eq 'HASH';

	# return $self->register_schema(
	# 	$url => $self->new( uri => $url, schema => $schema ) );
}

sub resolve_uri( $self, $uri, $base = undef ) {
	warn "resolving $uri";
	return _resolve_uri( $uri, $base // $self->uri );
}

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

		if( $fragment =~ m[^\.] ) {
			my $base_fragment = $base->fragment;
			$base_fragment .= '/' unless m[/$];

			my $path = URI->new($fragment);
			$path = $path->abs($base_fragment) if $base_fragment;
			$path = $path->canonical;

			$result->fragment($path) unless $path eq '/';
		}
		else {
			$result->fragment($fragment||undef);
		}

	} else {
		# not the same documents? fragment stays the same
		no warnings 'uninitialized';
		$result->fragment($uri->fragment||undef);
	}

	return $result;

}
