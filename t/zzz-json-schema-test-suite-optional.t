#!/usr/bin/env perl 

use 5.42.0;
use warnings;

use Test2::V1 -Pip;

use feature qw/ try /;

# for the bigfloat checks
BEGIN { $ENV{PERL_JSON_BACKEND} = 'JSON::backportPP'; }
use JSON;
use Path::Tiny 0.062;
use List::MoreUtils qw/ any /;
use Memoize;
use Data::Printer;
use Data::Dumper;

use JSON::Schema::AsType;
$JSON::Schema::AsType::strict_string = 1;

my $jsts_dir = path(__FILE__)->parent->child('json-schema-test-suite');

memoize('registry');

my ( $target_draft, $target_file, $target_test, $target_check ) = split ':',
  $ENV{TEST_SCHEMA} // '';

my $todo = {};

my @drafts = qw/ 3 4 6 7 2019-09 2020-12 /;

for my $draft (@drafts) {
	$todo->{$draft}{'ecmascript-regex.json'} = 'known TODO';
	$todo->{$draft}{'regex.json'} = 'known TODO';

	$todo->{$draft}{'uri.json'}{'validation of URIs'}{'invalid userinfo'} = 'TODO';

	$todo->{$draft}{'zeroTerminatedFloats.json'} = 'TODO';
}

$todo->{$_}{'bignum.json'} = "don't do bignums" for @drafts;

$todo->{$_}{'email.json'}{'validation of e-mail addresses'}
  {'full "From" header is invalid'} = 'TODO' for @drafts;

$todo->{$_}{'float-overflow.json'} = 'TODO' for qw/ 6 7 2019-09 2020-12 /;


my @optional_files = (
	'3',       'non-bmp-regex.json',
	'4',       'non-bmp-regex.json',
	'6',       'uri-reference.json',
	'6',       'uri-template.json',
	'6',       'non-bmp-regex.json',
	'6',       'unknownKeyword.json',
	'7',       'content.json',
	'7',       'cross-draft.json',
	'7',       'idn-email.json',
	'7',       'idn-hostname.json',
	'7',       'iri-reference.json',
	'7',       'iri.json',
	'7',       'relative-json-pointer.json',
	'7',       'time.json',
	'7',       'uri-reference.json',
	'7',       'uri-template.json',
	'7',       'non-bmp-regex.json',
	'7',       'unknownKeyword.json',
	'2019-09', 'anchor.json',
	'2019-09', 'cross-draft.json',
	'2019-09', 'dependencies-compatibility.json',
	'2019-09', 'duration.json',
	'2019-09', 'idn-email.json',
	'2019-09', 'idn-hostname.json',
	'2019-09', 'iri-reference.json',
	'2019-09', 'iri.json',
	'2019-09', 'relative-json-pointer.json',
	'2019-09', 'time.json',
	'2019-09', 'uri-reference.json',
	'2019-09', 'uri-template.json',
	'2019-09', 'uuid.json',
	'2019-09', 'no-schema.json',
	'2019-09', 'non-bmp-regex.json',
	'2019-09', 'refOfUnknownKeyword.json',
	'2019-09', 'unknownKeyword.json',
	'2020-12', 'anchor.json',
	'2020-12', 'cross-draft.json',
	'2020-12', 'dependencies-compatibility.json',
	'2020-12', 'dynamicRef.json',
	'2020-12', 'format-assertion.json',
	'2020-12', 'duration.json',
	'2020-12', 'email.json',
	'2020-12', 'idn-email.json',
	'2020-12', 'idn-hostname.json',
	'2020-12', 'iri-reference.json',
	'2020-12', 'iri.json',
	'2020-12', 'relative-json-pointer.json',
	'2020-12', 'time.json',
	'2020-12', 'uri-reference.json',
	'2020-12', 'uri-template.json',
	'2020-12', 'uuid.json',
	'2020-12', 'non-bmp-regex.json',
	'2020-12', 'refOfUnknownKeyword.json',
	'2020-12', 'unknownKeyword.json',
	'2020-12', 'hostname.json',
	'2019-09', 'hostname.json',
	'7',       'hostname.json',
);

for my ( $d, $f ) (@optional_files) {
	$todo->{$d}{$f} = 'known TODO';
}

test_draft( $_, $todo->{$_} )
  for filter_target( $target_draft,
	reverse @JSON::Schema::AsType::DRAFT_VERSIONS );

done_testing;

###################################

sub filter_target( $target, @entries ) {
	return @entries unless $target;
	return grep {
		$_ = $_->{description} if ref and ref ne 'Path::Tiny';
		/$target/
	} @entries;
}

sub test_draft( $draft, $todo ) {

	my @files;

	my $iter = $jsts_dir->child( 'tests', 'draft' . $draft, 'optional' )
	  ->iterator( { recurse => 1 } );

	while ( my $f = $iter->() ) {
		push @files, $f if $f->is_file;
	}

	subtest "draft$draft" => sub {
		test_file( $draft, $_, $todo )
		  for filter_target( $target_file, @files );
	};

}

sub test_file( $draft, $file, $todo = {} ) {

	my $data = from_json $file->slurp, { allow_nonref => 1 };

	my $TODO;
	$TODO = todo $_
	  for grep { $_ and not ref } $todo->{ path($file)->basename };

	# my $TODO = $todo->{ path($file)->basename };
	# if ( $TODO and not ref $TODO and not $ENV{HARNESS_ACTIVE} ) {
	# 	return;
	# }

	subtest $file => sub {
		for ( filter_target( $target_test, @$data ) ) {
			my $t = $todo;
			if ( ref $t ) {
				$t = $t->{ path($file)->basename };
			}
			if ( ref $t ) {
				$t = $t->{ $_->{description} };
			}
			test_suite( $draft, $_, $file, $t );

		}
	};
}

sub test_suite( $draft, $test, $file, $todo = {} ) {
	subtest $test->{description} => sub {

		my $TODO;
		if ( $todo and not ref $todo ) {
			$TODO = todo $todo;
			$todo = {};
		}

		# my $todo;
		# $todo = todo "known todo"
		#   if any { $test->{description} eq $_ } @$TODO;

		try {

			my $registry = registry($draft);

			my $schema = JSON::Schema::AsType->new(
				draft    => $draft,
				schema   => $test->{schema},
				registry => +{%$registry},
			);

			for ( @{ $test->{tests} } ) {
				my $desc = $_->{description};

				my $TODO;
				for my $key ( keys %$todo ) {
					next unless -1 < index $desc, $key;
					$TODO = todo $todo->{$key};
				}

				$desc .= ' (invalid)' unless $_->{valid};

				ok $schema->check( $_->{data} ) ^^ !$_->{valid}, $desc
				  or explain_failure( $schema, $_->{data}, $_->{valid} );

			  # local $TODO = 'known to fail'
			  #   if any { $desc eq $_ }
			  #   'a string is still not an integer, even if it looks like one',
			  #   'ignores non-strings',
			  #   'a string is still a string, even if it looks like a number',
			  #   'a string is still not a number, even if it looks like one';

	 # Test that the result from check is the same as what is in the spec.
	 # If the check should be true and the result is false, do validate_explain.
	 # try {
	 # 	is !!$schema->check( $_->{data} ) => !!$_->{valid},
	 # 	  $_->{description}
	 # 	  or do {

				# 		note $schema->type->display_name;
				# 		my $validation = $schema->validate_explain( $_->{data} );
				# 		note "explain: ", @$validation if $validation;
				# 		note Dumper( $schema->schema );
				# 		note Dumper( $_->{data} );
				# 		bail_out("TEST_SCHEMA defined, bailing out")
				# 		  if $ENV{'TEST_SCHEMA'}
				# 		  and ( !$ENV{HARNESS_ACTIVE} and !$todo );
				# 	  };
				# }
				# catch ($e) {
				# 	diag $e;
				# 	fail $_->{description};
				# 	note Dumper( $schema->schema );
				# 	note Dumper( $_->{data} );

				# 	bail_out("peace out") if $ENV{'TEST_SCHEMA'};
				# };

			}
		}
		catch ($e) {
			fail "test errored";
			note $e;
		}
	};

}

sub explain_failure( $schema, $data, $valid ) {
	return unless $ENV{TEST_SCHEMA};

	if ($valid) {
		note join "\n", $schema->validate_explain($data)->@*;
	}
	else {
		note "should have failed, but passed";
	}

	note Data::Dumper->Dump( [ $schema->schema, $data ], [qw/ schema data /] );
}

sub registry($draft) {
	my $remotes_dir = $jsts_dir->child('remotes');

	my $registry = JSON::Schema::AsType->new( draft => $draft, schema => {} );

	$remotes_dir->visit(
		sub {
			my $path = shift;
			return if $path =~ /draft/ and $path !~ /draft$draft/;
			return unless $path =~ qr/\.json$/;

			my $name = $path->relative($remotes_dir);

			$registry->register_schema( "http://localhost:1234/$name",
				from_json $path->slurp );

			return;

		},
		{ recurse => 1 }
	);

	return $registry->registry;
}
