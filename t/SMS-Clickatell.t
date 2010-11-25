# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl GNM-AlarmPointFuncs.t'

#########################

use Test::More; # tests => 2;

BEGIN {
	use_ok('Net::SMS::Clickatell::SOAP') ;
};

#########################

print "A Clickatell username, password and SOAP API ID is required for the rest of the tests.\nDo you wish to supply connection credentials? (y/N): ";
$connectionTests = <STDIN>;
if ($connectionTests =~ /[yY]/) {
	print "Enter your Clicktell credentials when prompted or type SKIP at any time to bypass the remaining tests\n";
	do {
		print "Clickatell user id (or SKIP): ";
		$user = <stdin>;
		chomp($user);
	} until length($user) > 1;	
	goto NOCRED if $user eq 'SKIP';

	do {
		print "Clickatell password (or SKIP): ";
		$password = <stdin>;
		chomp($password);
	} until length($password) > 1;
	goto NOCRED if $password eq 'SKIP';

	do {
		print "Clickatell api id (or SKIP): ";
		$api_id = <stdin>;
		chomp($api_id);
	} until length($api_id) > 1;
	goto NOCRED if $api_id eq 'SKIP';

} else {
	
NOCRED:
	$connectionTests = 'N';
	
}

SKIP: {
	
	skip "no connection credentials supplied", 6 unless $connectionTests =~ /[Yy]/ ;
	
	$obj = new SMS::Clickatell::SOAP(verbose=>0, user=>$user, password=>$password, api_id=>$api_id );
	isa_ok( $obj, 'SMS::Clickatell::SOAP' );

	like( $obj->ping, qr/OK:/, "ping()" );
	like( $obj->getbalance, qr/Credit:/, "getbalance()");
	like( $obj->routeCoverage( msisdn => '19991234567'), qr/OK:/,"routeCoverage()" );
	like( $obj->getmsgcharge( apiMsgId => 'xxx'), qr/apiMsgId:/,"getmsgcharge()" );
	like( $obj->delmsg( apiMsgId => 'xxx'), qr/ID:/,"delmsg()" );
   
}

done_testing();