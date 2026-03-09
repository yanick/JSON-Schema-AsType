#!/usr/bin/env perl 

use strict;
use warnings;

use JSON;
use Path::Tiny 0.062;
use JSON::Schema::AsType;
use List::MoreUtils qw/ any /;

use Test::More;

use lib 't/lib';

use TestUtils;

$::explain = 0;
$JSON::Schema::AsType::strict_string = 1;

my $jsts_dir = path( __FILE__ )->parent->child( 'json-schema-test-suite' );

# seed the external schemas
my $remote_dir = $jsts_dir->child('remotes');

my $registry = JSON::Schema::AsType->new(schema=>{});

$remote_dir->visit(sub{
    my $path = shift;
    return unless $path =~ qr/\.json$/;

    my $name = $path->relative($remote_dir);

    $registry->register_schema( 
        "http://localhost:1234/$name",
        from_json $path->slurp 
    );

    return;

},{recurse => 1});

my @files = @ARGV ? $jsts_dir->child('tests','draft6',shift @ARGV) : sort grep { $_->is_file } $jsts_dir->child( 'tests','draft6')->children;


run_tests_for(6,path($_)) for @files;

done_testing;





