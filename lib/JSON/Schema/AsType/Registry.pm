package JSON::Schema::AsType::Registry;

use 5.42.0;

use feature ':5.42';

use strict;
use warnings;

use JSON;
use LWP::Simple;
use Module::Runtime qw/ use_module /;

# TODO class instead?
use Moose::Role;

# TODO per-object
our $registry = {};

has schema_registry => (
    is => 'ro',
    lazy => 1,
    default => sub { $registry },
    traits => [ 'Hash' ],
    handles => {
        all_schemas       => 'elements',
        all_schema_uris       => 'keys',
        registered_schema => 'get',
        register_schema   => 'set',
    },
);

around register_schema => sub {
    # TODO Use a type instead to coerce into canonical
    my( $orig, $self, $uri, $schema ) = @_;
    $uri =~ s/#$//;
    $orig->($self,$uri,$schema);
};

sub fetch {
    my( $self, $url ) = @_;

	# is it one of the spec schemas?
	if( $url =~ qr[^https?://json-schema.org/draft-0?(.*)/schema] ) {
		return $self->register_schema( $url => 
			use_module('JSON::Schema::AsType::Draft'. $1)->new 
		);
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
