package JSON::Schema::AsType;
# ABSTRACT: generates Type::Tiny types out of JSON schemas

use 5.10.0;

use strict;
use warnings;

use Type::Tiny;
use Type::Tiny::Class;
use Scalar::Util qw/ looks_like_number /;
use List::Util qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int Object slurpy Dict Optional slurpy /; 
use Type::Utils;
use LWP::Simple;
use Clone 'clone';
use URI;
use Class::Load qw/ load_class /;

use Moose::Util qw/ apply_all_roles /;

use JSON;

use Moose;

use MooseX::MungeHas 'is_ro';
use MooseX::ClassAttribute;

no warnings 'uninitialized';

our $strict_string = 1;

class_has schema_registry => (
    is => 'ro',
    lazy => 1,
    default => sub { +{} },
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

has type => ( 
    is => 'rwp',
    handles => [ qw/ check validate validate_explain / ], 
    builder => 1, 
    lazy => 1 
);

has draft_version => (
    is => 'ro',
    lazy => 1,
    default => sub { 
        $_[0]->has_specification ? $_[0]->specification  =~ /(\d+)/ && $1 
            : eval { $_[0]->parent_schema->draft_version } || 4;
    },
    isa => enum([ 3, 4, 6 ]),
);

has spec => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->fetch( sprintf "http://json-schema.org/draft-%02d/schema", $_[0]->draft_version );
    },
);

has schema => ( 
    predicate => 'has_schema',
    lazy => 1,
    default => sub {
        my $self = shift;
            
        my $uri = $self->uri or die "schema or uri required";

        return $self->fetch($uri)->schema;
    },
);

has parent_schema => (
    clearer => 1,
);

has strict_string => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self  = shift;

        $self->parent_schema->strict_string if $self->parent_schema;

        return $JSON::Schema::AsType::strict_string;
    },
);

sub fetch {
    my( $self, $url ) = @_;

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
        return $schema;
    }

    my $schema = eval { from_json LWP::Simple::get($url) };

    $DB::single = not ref $schema;
    

    die "couldn't get schema from '$url'\n" unless ref $schema eq 'HASH';

    return $self->register_schema( $url => $self->new( uri => $url, schema => $schema ) );
}

has uri => (
    is => 'rw',
    trigger => sub {
        my( $self, $uri ) = @_;
        $self->register_schema($uri,$self);
        $self->clear_parent_schema;
} );

has references => sub { 
    +{}
};

has specification => (
    predicate => 1,
    is => 'ro',
    lazy => 1,
    default => sub { 
        return 'draft'.$_[0]->draft_version;
        eval { $_[0]->parent_schema->specification } || 'draft4' },
    isa => enum 'JsonSchemaSpecification', [ qw/ draft3 draft4 draft6 / ],
);

sub specification_schema {
    my $self = shift;

    $self->spec->schema;
}

sub validate_schema {
    my $self = shift;
    $self->spec->validate($self->schema);
}

sub validate_explain_schema {
    my $self = shift;
    $self->spec->validate_explain($self->schema);
}

sub root_schema {
    my $self = shift;
    eval { $self->parent_schema->root_schema } || $self;
}

sub is_root_schema {
    my $self = shift;
    return not $self->parent_schema;
}

sub sub_schema {
    my( $self, $subschema ) = @_;
    $self->new( schema => $subschema, parent_schema => $self );
}

sub absolute_id {
    my( $self, $new_id ) = @_;

    return $new_id if $new_id =~ m#://#; # looks absolute to me

    my $base = $self->ancestor_uri;

    $base =~ s#[^/]+$##;

    return $base . $new_id;
}

sub _build_type {
    my $self = shift;

    $self->_set_type('');

    my @types =
        grep { $_ and $_->name ne 'Any' }
        map  { $self->_process_keyword($_) } 
             $self->all_keywords;

    return @types ? reduce { $a & $b } @types : Any
}

sub all_keywords {
    my $self = shift;

    return sort map { /^_keyword_(.*)/ } $self->meta->get_method_list;
}

sub _process_keyword {
    my( $self, $keyword ) = @_;

    return unless exists $self->schema->{$keyword};

    my $value = $self->schema->{$keyword};

    my $method = "_keyword_$keyword";

    $self->$method($value);
}

# returns the first defined parent uri
sub ancestor_uri {
    my $self = shift;
    
    return $self->uri || eval{ $self->parent_schema->ancestor_uri };
}


sub resolve_reference {
    my( $self, $ref ) = @_;

    $ref = join '/', '#', map { $self->_escape_ref($_) } @$ref
        if ref $ref;

    if ( $ref =~ s/^([^#]+)// ) {
        my $base = $1;
        unless( $base =~ m#://# ) {
            my $base_uri = $self->ancestor_uri;
            $base_uri =~ s#[^/]+$##;
            $base =  $base_uri . $base;
        }
        return $self->fetch($base)->resolve_reference($ref);
    }

    $self = $self->root_schema;
    return $self if $ref eq '#';
    
    $ref =~ s/^#//;

#    return $self->references->{$ref} if $self->references->{$ref};

    my $s = $self->schema;

    my @refs = map { $self->_unescape_ref($_) } grep { length $_ } split '/', $ref;

    while( @refs ) {
        my $ref = shift @refs;
        my $is_array = ref $s eq 'ARRAY';

        $s = $is_array ? $s->[$ref] : $s->{$ref} or last;

        if( ref $s eq 'HASH' ) {
            if( my $local_id = $s->{id} || $s->{'$id'} ) {
                my $id  = $self->absolute_id($local_id);
                $self = $self->fetch( $self->absolute_id($id) );
                
                return $self->resolve_reference(\@refs);
            }
        }

    }

    return ( 
        ( ref $s eq 'HASH' or ref $s eq 'JSON::PP::Boolean' ) 
            ?  $self->sub_schema($s) 
            : Any );

}

sub _unescape_ref {
    my( $self, $ref ) = @_;

    $ref =~ s/~0/~/g;
    $ref =~ s!~1!/!g;
    $ref =~ s!%25!%!g;

    $ref;
}

sub _escape_ref {
    my( $self, $ref ) = @_;

    $ref =~ s/~/~0/g;
    $ref =~ s!/!~1!g;
    $ref =~ s!%!%25!g;

    $ref;
}

sub _add_reference {
    my( $self, $path, $schema ) = @_;

    $path = join '/', '#', map { $self->_escape_ref($_) } @$path
        if ref $path;

    $self->references->{$path} = $schema;
}

sub _add_to_type {
    my( $self, $t ) = @_;

    if( my $already = $self->type ) {
        $t = $already & $t;
    }

    $self->_set_type( $t );
}

sub BUILD {
    my $self = shift;
    # TODO rename specification to  draft_version 
    # and have specifications renamed to spec
    apply_all_roles( $self, 'JSON::Schema::AsType::' . ucfirst $self->specification );

    # TODO move the role into a trait, which should take care of this
    $self->type if $self->has_schema;
}

1;
