package JSON::Schema::AsType::Draft6;
# ABSTRACT: Role processing draft6 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

Importing this module auto-populate the Draft4 schema in the
L<JSON::Schema::AsType> schema cache.

=cut

use strict;
use warnings;

use Moose::Role;

use Type::Utils;
use Scalar::Util qw/ looks_like_number /;
use List::Util qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;
use Types::Standard qw/InstanceOf HashRef StrictNum Any Str ArrayRef Int slurpy Dict Optional slurpy /; 

use JSON;

use JSON::Schema::AsType;

use JSON::Schema::AsType::Draft6::Types '-all';

with 'JSON::Schema::AsType::Draft4';

override all_keywords => sub {
    my $self = shift;
    
    # $ref trumps all
    return '$ref' if $self->schema->{'$ref'};

    return uniq '$id', super();
};

override _build_type => sub {
    my $self = shift;

    return super() if ref $self->schema eq 'HASH';

    return $self->schema ? Any : ~Any;
    
};

sub _keyword_propertyNames {
    my( $self, $schema ) = @_;

    PropertyNames[ $self->sub_schema($schema)->type ];
}

sub _keyword_items {
    my( $self, $items ) = @_;

    if ( Boolean->check($items) ) {
        return if $items;
        return Items[Any];
    }

    if( ref $items eq 'HASH' ) {
        my $type = $self->sub_schema($items)->type;

        return Items[$type];
    }

    # TODO forward declaration not workie
    my @types;
    for ( @$items ) {
        push @types, $self->sub_schema($_)->type;
    }

    return Items[\@types];
}

sub _keyword_dependencies {
    my( $self, $dependencies ) = @_;

    return Dependencies[
        pairmap {
            $a => ( ref $b eq 'HASH' or ref $b eq 'JSON::PP::Boolean' ) ? $self->sub_schema($b) 
                    : $b } %$dependencies
    ];

}

__PACKAGE__->meta->add_method( '_keyword_$id' => sub {
        my $self = shift;
        $self->_keyword_id(@_);
} );

1;
