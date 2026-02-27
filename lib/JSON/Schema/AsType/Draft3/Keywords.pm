package JSON::Schema::AsType::Draft3::Keywords;
# ABSTRACT: Role processing draft3 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

Importing this module auto-populate the Draft3 schema in the
L<JSON::Schema::AsType> schema cache.

=cut

use strict;
use warnings;

use Moose::Role;

use Type::Utils;
use Scalar::Util qw/ looks_like_number /;
use List::Util qw/ reduce pairmap pairs /;
use List::MoreUtils qw/ any all none uniq zip /;

use JSON::Schema::AsType;

use JSON;

use JSON::Schema::AsType::Draft3::Types '-all';
use Types::Standard 'Optional';

with 'JSON::Schema::AsType::Draft4::Keywords' => {
    -excludes => [qw/ _keyword_properties _keyword_required _keyword_type /]
};

sub _keyword_properties {
    my( $self, $properties ) = @_;

    my @props = pairmap { {
        my $schema = $self->sub_schema($b);
        my $p = $schema->type;
        $p = Optional[$p] unless $b->{required};
        $a => $p
    }}  %$properties;

    return Properties[@props];
}

sub _keyword_disallow {
    Disallow[ $_[0]->_keyword_type($_[1]) ];
}


sub _keyword_extends {
    my( $self, $extends ) = @_;

    my @extends = ref $extends eq 'ARRAY' ? @$extends : ( $extends );

    return Extends[ map { $self->sub_schema($_)->type } @extends];
}

sub _keyword_type {
    my( $self, $struct_type ) = @_;

    my %type_map = map {
        lc $_->name => $_
    } Integer, Boolean, Number, String, Null, Object, Array;

    unless( $self->strict_string ) {
        $type_map{number} = LaxNumber;
        $type_map{integer} = LaxInteger;
        $type_map{string} = LaxString;
    }


    return if $struct_type eq 'any';

    return $type_map{$struct_type} if $type_map{$struct_type};

    if( my @types = eval { @$struct_type } ) {
        return reduce { $a | $b } map { ref $_ ? $self->sub_schema($_)->type : $self->_keyword_type($_) } @types;
    }

    die "unknown type '$struct_type'";
}

sub _keyword_divisibleBy {
    my( $self, $divisibleBy ) = @_;

    DivisibleBy[$divisibleBy];
}

sub _keyword_dependencies {
    my( $self, $dependencies ) = @_;

    return Dependencies[
        pairmap { $a => ref $b eq 'HASH' ? $self->sub_schema($b)->type : $b } %$dependencies
    ];

}


1;
