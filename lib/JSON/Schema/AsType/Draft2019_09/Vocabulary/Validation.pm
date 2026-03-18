package JSON::Schema::AsType::Draft2019_09::Vocabulary::Validation;
# ABSTRACT: Role processing draft7 JSON Schema 

=head1 DESCRIPTION

This role is not intended to be used directly. It is used internally
by L<JSON::Schema::AsType> objects.

=cut

use 5.42.0;
use warnings;

use feature qw/ module_true /;
use Types::Standard qw/Any/;

use Moose::Role;

use JSON::Schema::AsType::Draft2019_09::Types qw/ MaxContains MinContains /;

with 'JSON::Schema::AsType::Draft7::Keywords';

sub _keyword_maxContains($self,$max) {
    
    return Any unless $self->schema->{contains};

    return MaxContains[$max];
}

sub _keyword_minContains($self,$max) {
    
    return Any unless $self->schema->{contains};

    return MinContains[$max];
}


