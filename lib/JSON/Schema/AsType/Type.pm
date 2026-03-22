package JSON::Schema::AsType::Type;

use 5.42.0;
use warnings;

use feature 'signatures', 'module_true';

use Types::Standard qw/ Any /;
use List::Util qw/ reduce /;

use Moose::Role;
use MooseX::MungeHas 'is_ro';

has type => (
    is      => 'rwp',
    handles => [qw/ check validate validate_explain /],
    builder => 1,
    lazy    => 1
);

=pod
$JSON::Schema::AsType::Type::INDENT = 0;
around check => sub($orig,$self,$value) {

    use DDP;
    say "\t" x $JSON::Schema::AsType::Type::INDENT, "checking ", $self->uri;
    say "\t" x $JSON::Schema::AsType::Type::INDENT, $self->type->display_name;
    say "\t" x $JSON::Schema::AsType::Type::INDENT, "value ", np $value;

    local $JSON::Schema::AsType::Type::INDENT = $JSON::Schema::AsType::Type::INDENT + 1;
    my $verdict = $orig->($self,$value);


    say "\t" x --$JSON::Schema::AsType::Type::INDENT, "verdict: $verdict";

    return $verdict;

};
=cut

sub validate_schema {
    my $self = shift;
    $self->metaschema->validate( $self->schema );
}

sub validate_explain_schema {
    my $self = shift;
    $self->metaschema->validate_explain( $self->schema );
}

sub _build_type {
    my $self = shift;

    return $self->schema ? Any : ~Any 
        if JSON::is_bool( $self->schema );

    my @types = 
        grep { $_ and $_->name ne 'Any' }
        map { $self->_process_keyword($_) } 
            $self->all_active_keywords;

    return @types ? reduce { $a & $b } @types : Any;
}
