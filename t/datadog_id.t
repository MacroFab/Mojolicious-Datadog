use strict;
use warnings;
use Test::More;
use JSON::XS;
use MFab::Plugins::Datadog qw(datadogId);

# Test that datadogId returns a value
my $id = datadogId();
ok(defined $id, 'datadogId returns a defined value');

# Test that the value is a number
like($id, qr/^-?\d+$/, 'datadogId returns a numeric value');

# Test JSON::XS serialization
my $json = JSON::XS->new->encode({ id => $id });
like($json, qr/"id":-?\d+/, 'JSON encoded without quotes around the number');
unlike($json, qr/"id":"-?\d+"/, 'JSON encoded without string quotes');

# Test multiple calls produce different values
my $id2 = datadogId();
isnt($id, $id2, 'Multiple calls produce different values');

done_testing();
