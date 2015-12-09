package JSON::Schema::AsType;
our $AUTHORITY = 'cpan:YANICK';
# ABSTRACT: generates Type::Tiny types out of JSON schemas
$JSON::Schema::AsType::VERSION = '0.0.2';
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

__END__

=pod

=encoding UTF-8

=head1 NAME

JSON::Schema::AsType - generates Type::Tiny types out of JSON schemas

=head1 VERSION

version 0.0.2

=head1 SYNOPSIS

    use JSON::Schema::AsType;

    my $schema = JSON::Schema::AsType->new( schema => {
            properties => {
                foo => { type => 'integer' },
                bar => { type => 'object' },
            },
    });

    print 'valid' if $schema->check({ foo => 1, bar => { two => 2 } }); # prints 'valid'

    print $schema->validate_explain({ foo => 'potato', bar => { two => 2 } });

=head1 DESCRIPTION

This module takes in a JSON Schema (L<http://json-schema.org/>) and turns it into a
L<Type::Tiny> type.

=head1 METHODS

=head2 new( %args )

    my $schema = JSON::Schema::AsType->new( schema => $my_schema );

The class constructor. Accepts the following arguments.

=over

=item schema => \%schema

The JSON schema to compile, as a hashref. 

If not given, will be retrieved from C<uri>. 

An error will be thrown is neither C<schema> nor C<uri> is given.

=item uri => $uri

Optional uri associated with the schema. 

If provided, the schema will also 
be added to a schema cache. There is currently no way to prevent this. 
If this is an issue for you, you can manipulate the cache by accessing 
C<%JSON::Schema::AsType::EXTERNAL_SCHEMAS> directly.

=item specification => $version

The version of the JSON-Schema specification to use. Defaults to 'draft4' 
(and doesn't accept anything else  at the moment).

=back

=head2 type

Returns the compiled L<Type::Tiny> type.

=head2 check( $struct )

Returns C<true> if C<$struct> is valid as per the schema.

=head2 validate( $struct )

Returns a short explanation if C<$struct> didn't validate, nothing otherwise.

=head2 validate_explain( $struct )

Returns a log explanation if C<$struct> didn't validate, nothing otherwise.

=head2 schema

Returns the JSON schema, as a hashref.

=head2 parent_schema 

Returns the L<JSON::Schema::AsType> object for the parent schema, or
C<undef> is the current schema is the top-level one.

=head2 fetch( $url )

Fetches the schema at the given C<$url>. If already present, it will use the schema in
the cache. If not, the newly fetched schema will be added to the cache.

=head2 uri 

Returns the uri associated with the schema, if any.

=head2 specification

Returns the JSON Schema specification used by the object.

=head2 root_schema

Returns the top-level schema including this schema.

=head2 is_root_schema

Returns C<true> if this schema is a top-level
schema.

=head2 resolve_reference( $ref )

    my $sub_schema = $schema->resolve_reference( '#/properties/foo' );

    print $sub_schema->check( $struct );

Returns the L<JSON::Schema::AsType> object associated with the 
type referenced by C<$ref>.

=head1 SEE ALSO

=over

=item L<JSON::Schema>

=item L<JSV>

=back

=head1 AUTHOR

Yanick Champoux <yanick@babyl.dyndns.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
