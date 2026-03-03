package JSON::Schema::AsType::Visit;

sub visit {
    my ( $ref, $fcn ) = @_;
    my $ctx = { _depth => 0 };
    _visit( $ref, $fcn, $ctx );
    return $ctx;
}

sub _visit {
    my ( $ref, $fcn, $ctx ) = @_;
    my $type = ref($ref);
    croak("'$ref' is not an ARRAY or HASH")
      unless $type eq 'ARRAY' || $type eq 'HASH';
    my @elems = $type eq 'ARRAY' ? ( 0 .. $#$ref ) : ( sort keys %$ref );
    for my $idx (@elems) {
        my ( $v, $vr );
        $v  = $type eq 'ARRAY' ? $ref->[$idx]      : $ref->{$idx};
        $vr = $type eq 'ARRAY' ? \( $ref->[$idx] ) : \( $ref->{$idx} );
        local $_ = $v;
        # Wrap $fcn in dummy for loop to guard against bare 'next' in $fcn
        for my $dummy (0) { $fcn->( $idx, $vr, $ctx ) }
        if ( ref($v) eq 'ARRAY' || ref($v) eq 'HASH' ) {
            $ctx->{_depth}++;
			push $ctx->{_path}->@*, $idx;
            _visit( $v, $fcn, $ctx );
            $ctx->{_depth}--;
			pop $ctx->{_path}->@*;
        }
    }
}

1;
