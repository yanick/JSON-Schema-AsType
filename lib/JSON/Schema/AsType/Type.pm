package JSON::Schema::AsType::Type;

# ABSTRACT: JSON::Schema::AsType role providing all Type::Tiny methods

=head1 DESCRIPTION 

Internal module for L<JSON::Schema:::AsType>. 

=cut

use 5.42.0;
use warnings;

use feature 'signatures', 'module_true';

use Types::Standard qw/ Any /;
use List::Util      qw/ reduce /;
use Type::Tiny;

use Moose::Role;
use MooseX::MungeHas 'is_ro';

use JSON::Schema::AsType::Annotations;

has type => (
    is      => 'rwp',
    handles => [qw/ check validate validate_explain /],
    builder => 1,
    lazy    => 1
);

has base_type => (
    is      => 'ro',
    builder => 1,
    lazy    => 1,
);

sub validate_schema {
    my $self = shift;
    $self->metaschema->validate( $self->schema );
}

sub validate_explain_schema {
    my $self = shift;
    $self->metaschema->validate_explain( $self->schema );
}

sub _build_base_type {
    my $self = shift;

    return $self->schema ? Any : ~Any
      if JSON::is_bool( $self->schema );

    my @types =
      grep { $_ and $_->name ne 'Any' }
      map { $self->_process_keyword($_) } $self->all_active_keywords;

    return Type::Tiny->new(
	display_name => $self->uri,
	parent       => @types ? reduce { $a & $b } @types : Any,
    );
}

my $Scope = Type::Tiny->new(
    name                 => 'Scope',
    constraint_generator => sub {
	my $type = shift;
	return sub {
	    annotation_scope(
		sub {
		    $type->check($_);
		}
	    );
	}
    },
    deep_explanation => sub( $type, $value, $varname ) {
	my @whines;
	my $inner = $type->parameters->[0];
	push @whines, sprintf "%s was %s, and failed %s: %s",
	  $varname, $value, $inner->name, join "\n",
	  $inner->validate_explain($value)->@*;
	return \@whines;
    }
);

sub _build_type($self) {
    return $Scope->of( $self->base_type );
}
