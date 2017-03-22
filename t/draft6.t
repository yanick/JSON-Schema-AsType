#!/usr/bin/env perl 

use strict;
use warnings;

use JSON;
use Path::Tiny 0.062;
use JSON::Schema::AsType;
use List::MoreUtils qw/ any /;

use Test::More;

my $explain = 1;

my $jsts_dir = path( __FILE__ )->parent->child( 'json-schema-test-suite' );

# seed the external schemas
my $remote_dir = $jsts_dir->child('remotes');

$remote_dir->visit(sub{
    my $path = shift;
    return unless $path =~ qr/\.json$/;

    my $name = $path->relative($remote_dir);

    JSON::Schema::AsType->new( 
        uri    => "http://localhost:1234/$name",
        schema => from_json $path->slurp 
    );

    return;

},{recurse => 1});


@ARGV = grep { $_->is_file } $jsts_dir->child( 'tests','draft6')->children unless @ARGV;

run_tests_for(path($_)) for @ARGV;

sub run_tests_for {
    my $file = shift;

    subtest $file => sub {
        my $data = from_json $file->slurp, { allow_nonref => 1 };
        run_schema_test($_) for @$data;
    };
}

sub run_schema_test {
    my $test = shift;

    subtest $test->{description} => sub {
        my $schema = JSON::Schema::AsType->new( 
            draft_version => 6,
            schema => $test->{schema});

        diag explain $test->{schema} if $explain;

        for ( @{ $test->{tests} } ) {
            my $desc = $_->{description};
            local $TODO = 'known to fail'
                if any { $desc eq $_ } 
                    'a string is still not an integer, even if it looks like one',
                    'a string is still not a number, even if it looks like one'; 

            is !!$schema->check($_->{data}) => !!$_->{valid}, $_->{description} 
                or do {
                    diag explain $_->{data};
                    diag join "\n", @{$schema->validate_explain($_->{data})||[]};
                };

            diag join "\n", @{ $schema->validate_explain($_->{data}) }
                unless $_->{valid} or not $explain;
        }
    };

}

done_testing;





