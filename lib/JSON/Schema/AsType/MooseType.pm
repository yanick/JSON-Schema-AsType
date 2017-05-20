package JSON::Schema::AsType::MooseType;

use Moose;

extends 'Moose::Meta::TypeConstraint';

has json_type => ( is => 'ro' );

sub can_be_inlined { 0 }

has name => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->json_type->meta->name;
    },
);

sub constraint {
    my $type = $_[0]->json_type;
    return sub { $type->check(@_) };
}


1;
