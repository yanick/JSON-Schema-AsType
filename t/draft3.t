#!/usr/bin/perl 

use strict;
use warnings;

use JSON;
use Path::Tiny;
use JSON::Schema::AsType;

use Test::More;

my $explain = 0;

my $jsts_dir = path( 't', 'json-schema-test-suite' );

# seed the external schemas
my $remote_dir = $jsts_dir->child('remotes');

$remote_dir->visit(sub{
    my $path = shift;
    return unless $path =~ qr/\.json$/;

    my $name = $path->relative($remote_dir);

    JSON::Schema::AsType->new( 
        specification => 'draft3',
        uri    => "http://localhost:1234/$name",
        schema => from_json $path->slurp 
    );

    return;

},{recurse => 1});


@ARGV = grep { $_->is_file } $jsts_dir->child( 'tests','draft3')->children unless @ARGV;

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
            specification => 'draft3',
            schema => $test->{schema}
        );
        for ( @{ $test->{tests} } ) {
            is !!$schema->check($_->{data}) => !!$_->{valid}, $_->{description} 
                or diag join "\n", eval { @{$schema->validate_explain($_->{data})} };

            diag join "\n", @{ $schema->validate_explain($_->{data}) || [] }
                unless $_->{valid} or not $explain;
        }
    };

}

done_testing;





