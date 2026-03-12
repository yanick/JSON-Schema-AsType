package JSON::Schema::AsType::Draft4::Keywords;
# ABSTRACT: Role processing draft4 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

Importing this module auto-populate the Draft4 schema in the
L<JSON::Schema::AsType> schema cache.

=cut

use 5.42.0;

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

use JSON::Schema::AsType::Draft4::Types '-all';

override all_keywords => sub {
    my $self = shift;
    
    # $ref trumps all
    return '$ref' if $self->schema->{'$ref'};

    return uniq 'id', super();
};

__PACKAGE__->meta->add_method( '_keyword_$ref' => sub {
        my( $self, $ref ) = @_;

        my $schema;

        return Type::Tiny->new(
            name => 'Ref',
            display_name => "Ref($ref)",
            constraint => sub {
				my $v = $_;
				use JSON::Schema::AsType::Debug;
				debug( 'in ref for %s', $ref );
				$schema //= $self->resolve_reference($ref);

                my $result = $schema->check($v) || 0;

                return $result;
            },
            message => sub { 
                join "\n", "ref schema is " . to_json($schema->schema, { allow_nonref => 1 }),@{$schema->validate_explain($_)} 
            }
        );
} );

sub _keyword_id {
	# done as part of the initial visit
}

sub _keyword_definitions {
    my( $self, $defs ) = @_;

    $self->sub_schema( $defs->{$_}, "#./definitions/$_" ) for keys %$defs;

    return;
};

sub _keyword_pattern {
    my( $self, $pattern ) = @_;

    Pattern[$pattern];
}

sub _keyword_enum {
    my( $self, $enum ) = @_;
 
    Enum[@$enum];
}

sub _keyword_uniqueItems {
    my( $self, $unique ) = @_;

    return unless $unique;  # unique false? all is good

    return UniqueItems;
}

sub _keyword_dependencies {
    my( $self, $dependencies ) = @_;

    return Dependencies[
        pairmap { $a => ref $b eq 'HASH' ? $self->sub_schema($b, "#./dependencies/$a") : $b } 
		%$dependencies
    ];

}

sub _keyword_additionalProperties {
    my( $self, $addi ) = @_;

    my $add_schema;
    $add_schema = $self->sub_schema($addi,'#./additionalProperties') if ref $addi eq 'HASH';

    my @known_keys = (
        eval { keys %{ $self->schema->{properties} } },
        map { qr/$_/ } eval { keys %{ $self->schema->{patternProperties} } } );

    return AdditionalProperties[ \@known_keys, $add_schema ? $add_schema->type : $addi ];
}

sub _keyword_patternProperties {
    my( $self, $properties ) = @_;

    my %prop_schemas = pairmap {
        $a => $self->sub_schema($b, "#./patternProperties/$a")->type
    } %$properties;

    return PatternProperties[ %prop_schemas ];
}

sub _keyword_properties {
    my( $self, $properties ) = @_;

    Properties[
        pairmap { 
            my $schema = $self->sub_schema($b, "#./properties/$a");
            $a => $schema->type;
        }  %$properties
    ];

}

sub _keyword_maxProperties {
    my( $self, $max ) = @_;

    MaxProperties[ $max ];
}

sub _keyword_minProperties {
    my( $self, $min ) = @_;

    MinProperties[ $min ];
}

sub _keyword_required {
    my( $self, $required ) = @_;

    Required[@$required];
}

sub _keyword_not {
    my( $self, $schema ) = @_;
    Not[ $self->sub_schema($schema,'#./not') ];
}

sub _keyword_oneOf {
    my( $self, $options ) = @_;

    OneOf[ pairmap { $self->sub_schema( $b, "#./oneOf/$a" ) } indexed @$options ];
}


sub _keyword_anyOf {
    my( $self, $options ) = @_;

	my $i = 0;
    AnyOf[ map { $self->sub_schema($_,'#./anyOf/'.$i++)->type } @$options ];
}

sub _keyword_allOf {
    my( $self, $options ) = @_;

	my $i = 0;
    AllOf[ map { $self->sub_schema($_,"#./allOf/".$i++)->type } @$options ];
}

sub _keyword_type {
    my( $self, $struct_type ) = @_;

    my %keyword_map = map {
        lc $_->name => $_
    } Integer, Number, String, Object, Array, Boolean, Null;

	unless( $self->strict_string ) {
	$keyword_map{number} = LaxNumber;
	$keyword_map{integer} = LaxInteger;
	$keyword_map{string} = LaxString;
		}


    return $keyword_map{$struct_type}
        if $keyword_map{$struct_type};

    if( ref $struct_type eq 'ARRAY' ) {
        return AnyOf[map { $self->_keyword_type($_) } @$struct_type];
    }

    return;
}

sub _keyword_multipleOf {
    my( $self, $num ) = @_;

    MultipleOf[$num];
};

sub _keyword_maxItems {
    my( $self, $max ) = @_;

    MaxItems[$max];
}

sub _keyword_minItems {
    my( $self, $min ) = @_;

    MinItems[$min];
}

sub _keyword_maxLength {
    my( $self, $max ) = @_;

    MaxLength[$max];
}

sub _keyword_minLength {
    my( $self, $min ) = @_;

    return MinLength[$min];
}

sub _keyword_maximum {
    my( $self, $maximum ) = @_;

    return $self->schema->{exclusiveMaximum}
        ? ExclusiveMaximum[$maximum]
        : Maximum[$maximum];

}

sub _keyword_minimum {
    my( $self, $minimum ) = @_;

    if ( $self->schema->{exclusiveMinimum} ) {
        return ExclusiveMinimum[$minimum];
    }

    return Minimum[$minimum];
}

sub _keyword_additionalItems {
    my( $self, $s ) = @_;

	$DB::single = 1;
    # unless($s) {
    #     my $items = $self->schema->{items} or return;
    #     return if ref $items eq 'HASH';  # it's a schema, nevermind
    #     my $size = @$items;

    #     return AdditionalItems[$size];
    # }

    my $schema = $self->sub_schema($s,'#./additionalItems');

	# items is schema => additionalItems does nothing
	return Any if ref $self->schema->{items} eq 'HASH';

	# no items? it's always valid 
	return Any unless defined $self->schema->{items};


    my $to_skip  = ($self->schema->{items}||[])->@*;

    return AdditionalItems[$to_skip,$schema];

}

sub _keyword_items {
    my( $self, $items ) = @_;

    if ( Boolean->check($items) ) {
        return Items[$items];
    }

    if( ref $items eq 'HASH' ) {
        my $type = $self->sub_schema($items,'#./items')->type;

        return Items[$type];
    }

    # TODO forward declaration not workie
    my @types;
	my $i = 0;
    for ( @$items ) {
        push @types, $self->sub_schema($_,'#./items/'.$i++)->type;
    }

    return Items[\@types];
}

1;
