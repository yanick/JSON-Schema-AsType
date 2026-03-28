package JSON::Schema::AsType::Draft2020_12::Vocabulary::Applicator;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature qw/ module_true /;

use Moose::Role;

use Types::Standard qw/ Any ArrayRef /;
use JSON::Schema::AsType::Annotations;
use JSON::Schema::AsType::Draft4::Types       qw/ Boolean /;
use JSON::Schema::AsType::Draft2019_09::Types qw/ /;
use JSON::Schema::AsType::Draft2020_12::Types qw/ PrefixItems Items Contains/;

use JSON::Schema::AsType::Draft6::Keywords;

with 'JSON::Schema::AsType::Draft2019_09::Vocabulary::Applicator' =>
  { -excludes => [ map { "_keyword_$_" } qw/ contains items/ ] };

sub _keyword_prefixItems ( $self, $items, $keyword = 'prefixItems' ) {

    if ( Boolean->check($items) ) {
        return if $items;
        return PrefixItems [JSON::false];
    }

    if ( ref $items eq 'HASH' ) {
        my $type = $self->sub_schema( $items, "#./$keyword" )->type;

        return PrefixItems [$type];
    }

    # TODO forward declaration not workie
    my @types;
    my $i = 0;
    for (@$items) {
        push @types, $self->sub_schema( $_, "#./$keyword/" . $i++ )->type;
    }

    return PrefixItems [ \@types ];
}

sub _keyword_items {
    my ( $self, $s ) = @_;

    my $schema = $self->sub_schema( $s, '#./items' );

    # items is schema => additionalItems does nothing
    return Any if ref $self->schema->{prefixItems} eq 'HASH';

    my $to_skip = ( $self->schema->{prefixItems} || [] )->@*;

    return ~ArrayRef | Items [ $to_skip, $schema->type ];

}

sub _keyword_contains( $self, $schema ) {

    my $type = $self->sub_schema( $schema, '#./contains' )->type;

    my $contains = sub {
        my $v = $_;
        add_annotation( 'contains',
            grep { $type->check( $v->[$_] ) } 0 .. $_->$#* );
        return 1;
    };

    $contains = Contains [$type] & $contains
      unless exists $self->schema->{minContains}
      and $self->schema->{minContains} == 0;

    return ~ArrayRef | $contains;

}

__PACKAGE__->meta->add_method(
    '_keyword_$ref' => sub {
        my ( $self, $ref ) = @_;

        my $schema;

        return Type::Tiny->new(
            name         => 'Ref',
            display_name => "Ref($ref)",
            constraint   => sub {
                local $::DEEP = ( $::DEEP // 0 ) + 1;
                die if $::DEEP > 10;
                my $v = $_;

                $schema = $self->resolve_reference($ref);

                if ($schema) {
                    return $self->sub_schema( $schema->schema, $schema->uri )
                      ->type->check($v);
                }

                my $m = '_keyword_$dynamicRef';
                return $self->$m($ref);
            },
            message => sub {
                join "\n",
                  "ref schema is "
                  . to_json( $schema->schema, { allow_nonref => 1 } ),
                  @{ $schema->validate_explain($_) };
            }
        );
    }
);

__PACKAGE__->meta->add_method(
    '_keyword_$dynamicRef' => sub {
        my ( $self, $ref ) = @_;

        my $schema;

        return Type::Tiny->new(
            display_name => "DynamicRef($ref)",
            constraint   => sub {

                my $v = $_;

                if( $ref =~ /(.+?)#(.+)/ ) {
                    return $self->resolve_reference($ref)->base_type->check($v);
                }

                my $anchor;
                my $parent = $self;


                my $first_id;

                $DB::single = 1;

                $ref =~ s/^#//;

                $DB::single = 1;

                while ( $parent = $parent->parent_schema ) {

                    $anchor = $parent->_find_dynamicAnchor($ref) and last;

                }

                die "anchor $ref not found\n" unless $anchor;

                # use DDP; p $anchor->schema;
                # warn "checking for $v\n";
                return $anchor->base_type->check($v);
            },
        );
    }
);
