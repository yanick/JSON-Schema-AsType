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
use Class::Load qw/ load_class /;

use Moose::Util qw/ apply_all_roles /;

use JSON;

use Moose;

use MooseX::MungeHas 'is_ro';

no warnings 'uninitialized';

our %EXTERNAL_SCHEMAS;

has type   => ( is => 'rwp', handles => [ qw/ check validate validate_explain / ], builder => 1, lazy => 1 );

has schema => ( isa => 'HashRef', lazy => 1, default => sub {
    my $self = shift;
        
    my $uri = $self->uri or die "schema or uri required";

    return $self->fetch($uri)->schema;
});


has parent_schema => ();

sub fetch {
    my( $self, $url ) = @_;

    unless ( $url =~ m#^\w+://# ) { # doesn't look like an uri
        $url = $self->schema->{id} . $url;
            # such that the 'id's can cascade
        if ( my $p = $self->parent_schema ) {
            return $p->fetch( $url );
        }
    }

    return $EXTERNAL_SCHEMAS{$url} if eval { $EXTERNAL_SCHEMAS{$url}->schema };

    my $schema = eval { from_json LWP::Simple::get($url) };

    die "couldn't get schema from '$url'\n" unless ref $schema eq 'HASH';

    return $EXTERNAL_SCHEMAS{$url} = $self->new( uri => $url, schema => $schema );
}

has uri => ( trigger => sub {
        $EXTERNAL_SCHEMAS{$_[1]} ||= $_[0];
} );

has references => sub { 
    +{}
};

has specification => (
    is => 'ro',
    lazy => 1,
    default => sub { eval { $_[0]->parent_schema->specification } || 'draft4' },
    isa => enum 'JsonSchemaSpecification', [ qw/ draft3 draft4 / ],
);

sub specification_schema {
    my $self = shift;

    my $spec = $self->specification;

    my $class  = "JSON::Schema::AsType::" . ucfirst $spec;

    load_class( $class );

    return eval '$'.$class . "::SpecSchema";
}

sub validate_schema {
    my $self = shift;
    $self->specification_schema->validate($self->schema);
}

sub validate_explain_schema {
    my $self = shift;
    $self->specification_schema->validate_explain($self->schema);
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

sub _build_type {
    my $self = shift;
    
    $self->_set_type('');

    $self->_process_keyword($_) 
        for sort map { /^_keyword_(.*)/ } $self->meta->get_method_list;

    $self->_set_type(Any) unless $self->type;

    $self->references->{''} = $self->type;
}

sub _process_keyword {
    my( $self, $keyword ) = @_;

    my $value = $self->schema->{$keyword} // return;

    my $method = "_keyword_$keyword";

    my $type = $self->$method($value) or return;

    $self->_add_to_type($type);
}


sub resolve_reference {
    my( $self, $ref ) = @_;

    $ref = join '/', '#', map { $self->_escape_ref($_) } @$ref
        if ref $ref;
    
    if ( $ref =~ s/^([^#]+)// ) {
        return $self->fetch($1)->resolve_reference($ref);
    }


    return $self->root_schema->resolve_reference($ref) unless $self->is_root_schema;

    return $self if $ref eq '#';
    
    $ref =~ s/^#//;

    return $self->references->{$ref} if $self->references->{$ref};

    my $s = $self->schema;

    for ( map { $self->_unescape_ref($_) } grep { length $_ } split '/', $ref ) {
        $s = ref $s eq 'ARRAY' ? $s->[$_] : $s->{$_} or last;
    }

    my $x;
    if($s) {
        $x = $self->sub_schema($s);
    }

    $self->references->{$ref} = $x;

    $x;
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
    apply_all_roles( $self, 'JSON::Schema::AsType::' . ucfirst $self->specification );
}

1;
