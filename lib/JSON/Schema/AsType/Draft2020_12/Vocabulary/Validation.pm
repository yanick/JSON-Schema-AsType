package JSON::Schema::AsType::Draft2020_12::Vocabulary::Validation;

# ABSTRACT: Role processing draft7 JSON Schema

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature         qw/ module_true signatures /;
use Types::Standard qw/Any /;
use List::Util      qw/ pairmap /;

use Moose::Role;

use JSON::Schema::AsType::Draft4::Types qw/ Boolean /;
use JSON::Schema::AsType::Draft2019_09::Types qw/ /;
use JSON::Schema::AsType::Draft2020_12::Types qw/ PrefixItems /;

use JSON::Schema::AsType::Draft6::Keywords;

with 'JSON::Schema::AsType::Draft2019_09::Vocabulary::Validation' => { -exclude => [] };

sub _keyword_prefixItems ( $self, $items, $keyword = 'prefixItems' ){

    if ( Boolean->check($items) ) {
        return if $items;
        return PrefixItems[JSON::false];
    }

    if( ref $items eq 'HASH' ) {
        my $type = $self->sub_schema($items,"#./$keyword")->type;

        return PrefixItems[$type];
    }

    # TODO forward declaration not workie
    my @types;
	my $i = 0;
    for ( @$items ) {
        push @types, $self->sub_schema($_,"#./$keyword/".$i++)->type;
    }

    return PrefixItems[\@types];
}
