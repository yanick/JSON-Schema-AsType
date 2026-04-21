#!/usr/bin/env perl

use 5.42.0;

use Path::Tiny;
use JSON;
use Data::Printer;
use TAP::Parser;

my @lines =
  map { s/^(\s*)//; { indent => length($1) / 4, test => $_ } }
  grep { /^\s*(not )?ok\s+\S/ } path(shift)->lines;

for (@lines) {
	$_->{test} =~ /(not ok|ok) \d+ - (.*?)(?: \{)?$/g;
	$_->{passed} = $1 eq 'ok';
	$_->{name}   = $2;
	$_->{name} =~ s#t/.*draft[\d-]+/##;
	$_->{todo} = $1 if $_->{test} =~ /# TODO (.*)/;
}

my @tests = ( { test => 'main', subtests => [], indent => -1 } );
my @level = $tests[0];

for my $l (@lines) {
	pop @level while $level[-1]->{indent} >= $l->{indent};

	$level[-1]->{subtests} //= [];
	push $level[-1]->{subtests}->@*, $l;
	push @level,                     $l;
}

@tests = $tests[0]->{subtests}->@*;

use DDP;

process_test($_) for @tests;

print <<~END;
	<style>
		details {
			max-width: 60em;
			margin-left: 2em;
			margin-bottom: 0.5em;
		}	
		summary {
			display: flex;
		}
		.name { 
			flex: 1;
		}
		button { margin-bottom: 1em; }
	</style>
	<button onclick="document.querySelectorAll('.all-passed').forEach( elt => elt.hidden = true)">hide successes</button>
END
print_html($_) for @tests;

# my %x = map print_todos($_) => @tests;
# use Data::Dumper;
# say Dumper( \%x );

sub print_html($t) {

	#return if $t->{passed} == $t->{total};

	if ( $t->{subtests} ) {
		my $percent    = int 100 * $t->{passed} / $t->{total};
		my $all_passed = $t->{passed} == $t->{total};
		print <<~"END";
			<details open class="@{[ 'all-passed' x !!$all_passed]}">
				<summary>
				<span class="name">@{[ $t->{ name } ]}</span>
				<span>@{[ $t->{passed}]}/@{[ $t->{total }]} ($percent%)</span>
				</summary>
		END

		print_html($_) for $t->{subtests}->@*;

		print "</details>";
		return;

	}

	print <<~"END";
		<div>
			<span>@{[ $t->{ name } ]}</span>
			<span>@{[ $t->{todo}]}</span>
		</div>
	END

}

sub print_todos($t) {

	return () if $t->{passed} == $t->{total};

	unless ( $t->{subtests} ) {
		return ( $t->{name} => $t->{todo} // 'TODO' );
	}

	return $t->{name} => +{ map { print_todos($_) } $t->{subtests}->@* };

}

sub process_test( $t, $indent = 0 ) {

	my ( $passed, $total ) = ( 0, 0 );
	my @lines;
	if ( $t->{subtests} ) {
		for ( $t->{subtests}->@* ) {
			process_test( $_, $indent + 1 );
			$passed += $_->{passed};
			$total  += $_->{total};
		}
		$t->{passed} = $passed;
		$t->{total}  = $total;
		return;
	}

	$t->{total} = 1;
}

__END__

my @tests = process_subtest( path('./results.tap')->slurp );

print_test($_) for @tests;

sub print_test( $t, $indent = 0 ) {
    say "  " x $indent, $t->[0]->description;
    print_test( $_, $indent + 1 ) for $t->@[ 1 .. $t->$#* ];

}

sub process_subtest($subtest) {
    $subtest =~ /^(\s*)/;
    $subtest =~ s/^$1//mg;

    return () unless $subtest;

    my $parser = TAP::Parser->new( { source => $subtest } );

    my @results;
    while ( my $result = $parser->next ) {
        push @results, $result if $result->is_test or $result->is_unknown;
    }

    my @tests;
    while (@results) {
        my @t = shift @results;
        my $subtest;
        while ( @results and $results[0]->is_unknown ) {
            $subtest .= ( shift @results )->as_string . "\n";
        }
        push @t,     process_subtest($subtest);
        push @tests, \@t;
    }

    return \@tests;

}
