use Test2::V1 -Pip;

use JSON::Schema::AsType::Registry;

subtest basic => sub {
	my $registry = JSON::Schema::AsType::Registry->new;

	my $uri = 'http://something.com/foo';
	my $schema = { type => 'boolean' };

	$registry->add( $uri, $schema );

	is [ $registry->all_uris ], bag {
		item $uri;
	};

}

done_testing;



