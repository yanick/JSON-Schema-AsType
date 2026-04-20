package JSON::Schema::AsType::Visit;

# ABSTRACT: Visit each node of a schema.

=head1 DESCRIPTION 

Internal module for L<JSON::Schema:::AsType>. Slightly tweaked version of 
L<Data::Visitor::Tiny>.

=cut

use 5.42.0;
use warnings;

use Carp;

use feature qw/ signatures /;

sub visit {
    my ( $ref, $fcn ) = @_;
    my $ctx = { _depth => 0 };
    _visit( $ref, $fcn, $ctx );
    return $ctx;
}

sub _visit {
    my ( $ref, $fcn, $ctx ) = @_;
    my $type = ref($ref);
    return if $type eq 'JSON::PP::Boolean';
    croak("'$ref' is not an ARRAY or HASH")
      unless $type eq 'ARRAY' || $type eq 'HASH';
    my @elems = $type eq 'ARRAY' ? ( 0 .. $#$ref ) : ( sort keys %$ref );
    for my $idx (@elems) {
        my ( $v, $vr );
        $v  = $type eq 'ARRAY' ? $ref->[$idx]      : $ref->{$idx};
        $vr = $type eq 'ARRAY' ? \( $ref->[$idx] ) : \( $ref->{$idx} );
        local $_ = $v;

        $fcn->( $idx, $vr, $ctx );
        if ( ref($v) eq 'ARRAY' || ref($v) eq 'HASH' ) {
            $ctx->{_depth}++;
            push $ctx->{_path}->@*, $idx;
            _visit( $v, $fcn, $ctx );
            $ctx->{_depth}--;
            pop $ctx->{_path}->@*;
        }
    }
}

sub walk($struct,$func,$path=undef,$root=undef) {

	my $ref = ref $struct or return;

	unless($path) {
		$path = [];
		$root = $struct;
	}

	if( $ref eq 'HASH') {
		for my $key ( sort keys %$struct ) {
			# $key, $value, $parent, $path, $root
			local $_ = $struct->{$key};
			my @path = (@$path,$key);
			my $result = $func->( $key, $_, $struct, \@path, $root );
			no warnings qw/ uninitialized /;
			walk($struct->{$key},$func,\@path,$root) unless $result eq 'STOP';
		}
		return;
	}

	if( $ref eq 'ARRAY') {
		for my $i ( 0..$struct->$#* ) {
			# $key, $value, $parent, $path, $root
			local $_ = $struct->[$i];
			my @path = (@$path,$i);
			my $result = $func->( $i, $_, $struct, \@path, $root );
			no warnings qw/ uninitialized /;
			walk($struct->[$i],$func,\@path,$root) unless $result eq 'STOP';
		}
		return;
	}

}


1;
