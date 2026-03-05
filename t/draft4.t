#!/usr/bin/env perl 

use strict;
use warnings;

use JSON;
use Path::Tiny 0.062;
use List::MoreUtils qw/ any /;

use Test::More;

use JSON::Schema::AsType;
$JSON::Schema::AsType::strict_string = 1;

my $explain = 0;

my $jsts_dir = path( __FILE__ )->parent->child( 'json-schema-test-suite' );

# seed the external schemas
my $remote_dir = $jsts_dir->child('remotes');

$remote_dir->visit(sub{
		return;
    my $path = shift;
    return unless $path =~ qr/\.json$/;

    my $name = $path->relative($remote_dir);

    JSON::Schema::AsType->new( 
        uri    => "http://localhost:1234/$name",
        schema => from_json $path->slurp 
    );

    return;

},{recurse => 1});


my @files = @ARGV ? $jsts_dir->child('tests','draft4',shift @ARGV) : grep { $_->is_file } $jsts_dir->child( 'tests','draft4')->children;

run_tests_for(path($_)) for @files;

sub run_tests_for {
    my $file = shift;

    subtest $file => sub {
        my $data = from_json $file->slurp, { allow_nonref => 1 };
		if(@ARGV) {
			@$data = grep { $_->{description} eq $ARGV[0] } @$data;
		}
        run_schema_test($_) for @$data;
    };
}

sub run_schema_test {
    my $test = shift;

    subtest $test->{description} => sub {
        my $schema = JSON::Schema::AsType->new( schema => $test->{schema});
        for ( @{ $test->{tests} } ) {
            my $desc = $_->{description};
            local $TODO = 'known to fail'
                if any { $desc eq $_ } 
                    'a string is still not an integer, even if it looks like one',
                    'ignores non-strings',
                    'a string is still a string, even if it looks like a number',
                    'a string is still not a number, even if it looks like one'; 

            # Test that the result from check is the same as what is in the spec.
            # If the check should be true and the result is false, do validate_explain.
            is !!$schema->check($_->{data}) => !!$_->{valid}, $_->{description}
                or $_->{valid} and diag join "\n", @{$schema->validate_explain($_->{data})} or do {



				note "explain: ", $schema->validate_explain($_->{data}) 
					unless !!$_->{valid};
				note explain $schema->schema;
				note explain $_->{data};
				note $schema->type->display_name;
			};

            diag join "\n", @{ $schema->validate_explain($_->{data}) }
                unless $_->{valid} or not $explain;
        }
    };

}

done_testing;





