package JSON::Schema::AsType::Registry;

use 5.42.0;

use feature 'signatures';

use strict;
use warnings;

use JSON;
use LWP::Simple qw//;
use Module::Runtime qw/ use_module /;

use Moose::Role;

has registry => (
    is => 'ro',
    lazy => 1,
    default => sub { +{} },
    traits => [ 'Hash' ],
    handles => {
        all_schema_uris   => 'keys',
        register_schema   => 'set',
    },
);


around register_schema => sub {
    # TODO Use a type instead to coerce into canonical
    my( $orig, $self, $uri, $schema ) = @_;

    $uri =~ s/#$//;

	unless( $schema isa JSON::Schema::AsType ) {
		$schema = JSON::Schema::AsType->new( schema => $schema, registry => $self->registry );
	}

    $orig->($self,$uri,$schema);
};

sub registered_schema($self,$uri) {
	return $self->registry->{$uri};

}

sub fetch {
    my( $self, $url ) = @_;

	# is it one of the spec schemas?
	if( $url =~ qr[^https?://json-schema.org/draft-0?(.*)/schema] ) {
		return $self->register_schema( $url => 
			use_module('JSON::Schema::AsType::Draft'. $1)->new 
		);
	}

	if(!$self->uri) {
		$DB::single = 1;
	}

    unless ( $url =~ m#^\w+://# ) { # doesn't look like an uri
        my $id =$self->uri;
        $id =~ s#[^/]*$##;
        $url = $id . $url;
            # such that the 'id's can cascade
        if ( my $p = $self->parent_schema ) {
            return $p->fetch( $url );
        }
    }

    $url = URI->new($url);
    $url->path( $url->path =~ y#/#/#sr );
    $url = $url->canonical;

    if ( my $schema = $self->registered_schema($url) ) {
        return $schema if $schema->has_schema;
    }

    my $schema = eval { from_json LWP::Simple::get($url) };

    die "couldn't get schema from '$url'\n" unless ref $schema eq 'HASH';

    return $self->register_schema( $url => $self->new( uri => $url, schema => $schema ) );
}

sub resolve_uri($self,$uri,$base=undef) {
	return _resolve_uri($uri,$base//$self->uri);
}

sub _resolve_uri {
	my ($uri,$base) = map { ref ? $_ : URI->new($_) } @_;

	return $uri unless $base;

	my $result = URI->new($uri)->abs($base)->canonical;

	# let's look at those fragments
	my $uri_doc = $uri->clone;
	$uri_doc->fragment(undef);
	my $base_doc = $base->clone;
	$base_doc->fragment(undef);

	# not the same documents? fragment stays the same
	unless( $uri_doc->eq($base_doc) ) {
		no warnings qw/ uninitialized /;
		my $fragment = $uri->fragment =~ s/^#//r;
		my $base_fragment = $base->fragment =~ s/^#//r;
		$base_fragment .= '/' unless m[/$] ;

		my $path = URI->new($fragment);
		$path = $path->abs($base_fragment) if $base_fragment;
		$path = $path->canonical;

		$result->fragment($path) unless $path eq '/';
	}

	return $result;

}
