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

$JSON::Schema::AsType::EXTERNAL_SCHEMAS{'http://localhost:1234/integer.json'}
    = JSON::Schema::AsType->new( schema => from_json $remote_dir->child( 'integer.json' )->slurp );

$JSON::Schema::AsType::EXTERNAL_SCHEMAS{'http://localhost:1234/subSchemas.json'}
    = JSON::Schema::AsType->new( schema => from_json $remote_dir->child('subSchemas.json' )->slurp );

$JSON::Schema::AsType::EXTERNAL_SCHEMAS{'http://localhost:1234/folder/folderInteger.json'}
    = JSON::Schema::AsType->new( schema => from_json $remote_dir->child( 'folder', 'folderInteger.json' )->slurp );

@ARGV = grep { $_->is_file } $jsts_dir->child( 'tests','draft4')->children unless @ARGV;

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
        my $schema = JSON::Schema::AsType->new( schema => $test->{schema});
        for ( @{ $test->{tests} } ) {
            is !!$schema->check($_->{data}) => !!$_->{valid}, $_->{description} 
                or diag join "\n", @{$schema->validate_explain($_->{data})};

            diag join "\n", @{ $schema->validate_explain($_->{data}) }
                unless $_->{valid} or not $explain;
        }
    };

}

done_testing;





