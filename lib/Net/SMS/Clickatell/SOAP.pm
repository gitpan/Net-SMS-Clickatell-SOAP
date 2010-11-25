package Net::SMS::Clickatell::SOAP;
#####################################################################
##	Net::SMS::Clickatell::SOAP
##	
##	Access the Clickatell Bulk SMS gateway using the SOAP
##	protocol.
##
##	$Id: SOAP.pm,v 1.3 2010/11/24 23:47:26 pfarr Exp $
#####################################################################

use 5.008008;
use strict;
use warnings;
use vars qw(@ISA $VERSION);
use SOAP::Lite
#TODO Clean this up
#	+trace
#	=> [ 'all' ]
#	=> [ qw(
#		result
#		trace
#		parameters
#	) ]
#		transport
	;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	ping
	routeCoverage
	getbalance
	sendmsg
	querymsg
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

use version; $VERSION = qv('0.01');

#TODO Fix and expand the SYNOPSIS
=head1 NAME

Net::SMS::Clickatell::SOAP - Clickatell SMS service via SOAP

=head1 SYNOPSIS

	use SMS::Clickatell::SOAP;

	my $sms = new SMS::Clickatell::SOAP(
		connection => (
			proxy => $PROXY_URL,
			service => $SERVICE_URL,
			verbose => $VERBOSE,
			user	=> $WS_USER,
			password => $WS_PASSWD,
			api_id => 123456,
		)
	);

=head1 DESCRIPTION

Pure Perl methods to interface with the Clickatell Bulk SMS service.

=head2 EXPORT

=over

=item ping 

=item sendMsg

=item queryMsg

=item stopMsg 

=item queryBalance 

=item queryCoverage

=back

=head1 METHODS

=cut


## Globals
my (
	$VERBOSE,
);

###############################################################################

=head2 new()

Class constructor method instantiates a class object and initiates a connection
to the Clickatell service through the auth call.

=head3 usage

 my $hSMS = new SMS::Clickatell::SOAP(
 	api_id => $apiId,
	user	=> $user,
	password => $password,
 	proxy   => $endpoint,
 	service => "${endpoint}?wsdl",
	verbose => 0
 );

=over

=item api_id (required)

Clickatell assigned api_id value.

=item user (required)

Clickatell account user ID.

=item password (required)

Clickatell account password.

=item proxy (optional)

SOAP connection parameter. See SOAP::Lite for further information. Defaults to
http://api.clickatell.com/soap/webservice.php.

=item service (optional)

SOAP connection parameter. See SOAP::Lite for further information. Defaults to
http://api.clickatell.com/soap/webservice.php?wsdl.

=item verbose

Verbosity level for debugging. Default is verbose=>0 (only error output).

=back

=cut

sub new {

	my (
		$status,
		$session_id,
		$result,
		$proxy,
		$service,
	);
	
	my ($class, %params) = @_;
	$VERBOSE = $params{verbose};	# Easier and more readable as $VERBOSE
	
	## Set default connection parameters if they were not passed.
	if ( exists $params{'proxy'} && defined $params{'proxy'} ) {
		$proxy  = $params{'proxy'};
	} else {
		$proxy  = "http://api.clickatell.com/soap/webservice.php";
		$params{'proxy'} = $proxy;
	}
	if ( exists $params{'service'} && defined $params{'service'} ) {
		$service  = $params{'service'};
	} else {
		$service  = $proxy . '?wsdl';
		$params{'service'} = $service;
	}

	## Initialize our class object, bless it and return it
	my $self = {
		_status 	=> 0,			# Status of the connection (0 or 1)
		_som		=> undef,		# Pointer to connection object
		_last_result => undef,		# Save the last result code
		_session_id	=> undef, 		# Session ID from Clickatell
		_params 	=> \%params,	# Save the passed parms in our object instance
		_verbose	=> $params{'verbose'},
	};
	bless $self, $class;
	
	## Connect to the AlarmPoint web server	
	print "Connecting to service at $params{proxy}... " if $VERBOSE;
	my $sms = new SOAP::Lite(
		proxy   => $proxy,
		service => $service,
	);
	
	## If the basic connection was made then establish a session and save
	## the SOAP object for later reference
	if ( $sms ) {
		print "connected!\n" if $VERBOSE;
		$self->{'_som'} = $sms;
		
		my $response = $sms->call( auth =>
				SOAP::Data->name( 'user'   	=> $params{'user'} ),
				SOAP::Data->name( 'password'=> $params{'password'} ),
				SOAP::Data->name( 'api_id' 	=> $params{'api_id'} ),
			);
		
		## If the session was established successfully the response will be
		## "OK: <sesion_id>"
		$result = $self->checkResult( $response );
		if ( $result =~ /OK:\s+(\S+)/ ) {
			$self->{'_session_id'} = $1;
			$self->{'_status'} = 1;
			printf STDERR "Session ID %s has been assigned\n", $1
				if $VERBOSE;
		} else {
			print STDERR "Error '$result' while establishing session\n"
				if $VERBOSE;
		}
		
	}
	
	return $self;
}

###############################################################################
## 	checkResult()
##
##	Internal function to check the status of a SOAP method call
##
## Parameters
##	SOM object
##
## Returns
## 	This subroutine returns a string based on the SOAP result envelope.
## 	If all went well it should return "OK". If not then it will return
## 	either the faultcode (if a SOAP fault occurred) or the result
## 	string if there was a method error on the server side.

sub checkResult {

	my ($self, $response) = @_;
	
	my $VERBOSE = $self->{'_verbose'};

	if ( $response->fault ) {
		printf STDERR "A %s fault has occurred: %s\n", $response->faultcode,
		$response->faultstring;
		return $response->fault();
	} else {
		if ( ref($response->result) eq "" ) {
			printf STDERR "\tReceived response: '%s'\n", $response->result if $VERBOSE > 1;
			$self->{'_last_result'} = $response->result;
			return $response->result;
		} elsif ( ref($response->result) eq "ARRAY" ) {
			my $return = '';
			foreach my $element ( @{$response->result} ) {
				$return .= "$element; ";
				$self->{'_last_result'} = $return;
				return $return;
			}
		} else {
			return "ERROR: I don't know how to handle a '" . ref($response->result) . "' result\n";
		}
	}

}

###############################################################################

=head2 ping()

Send a ping to the service to keep the session alive.

=head3 Usage

my $resp = $hSMS->ping();

=head3 Returns

=over

=item OK:

=item error message

=back

=cut

sub ping {

	my ($self) = @_;
	printf STDERR "pinging on session '%s'... ", $self->{'_session_id'}
		if $VERBOSE;
	
	my $response = $self->{'_som'}->call( ping =>
			SOAP::Data->name( 'session_id'   => $self->{'_session_id'} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 getbalance()

Query the number of credits available in the account.

=head3 Usage

my $resp = $hSMS();

=head3 Returns

=over

=item Credit: nn.nnn

Amount of outstanding credit balance for the account.

=item error message

=back

None.

=cut

sub getbalance {
	
	my ($self, %data) = @_;
	
	printf STDERR "getbalance %s... ", $self->{'_session_id'} if $VERBOSE;

	my $response = $self->{'_som'}->call( getbalance =>
			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 routeCoverage()

Chck the coverage of a network or number without sending a message.

=head3 Usage

 my $resp = $hSMS->routeCoverage(
	msisdn => $msisdn
 );

=over

=item msisdn

The network or number to be checked for coverage.

=back

=head3 Returns

=over

=item OK: followed by coverage information

Eg. OK: This prefix is currently supported. Messages sent to this prefix will be routed. Charge: 0.33

=item error message

=back

=cut

sub routeCoverage {
	
	my ($self, %data) = @_;
	
	printf STDERR "routeCoverage %s... ", $data{'msisdn'} if $VERBOSE;

	my $response = $self->{'_som'}->call( routeCoverage =>
			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
			SOAP::Data->name( 'msisdn' => $data{'msisdn'} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 querymsg()

Query the status of a message.

=head3 Usage

$resp = $hSMS->querymsg( apiMsgId => $apiMsgId );
$resp = $hSMS->querymsg( cliMsgId => $cliMsgId );

=over

=item apiMsgId

API message id (apiMsgId) returned by the gateway after a message was sent.

=item cliMsgId

client message ID (cliMsgId) you used on submission of the message.

=back

=head3 Returns

=over

=item ID: followed by message status

eg. ID: 18e8221e5aa50cfad72376e08f40388a Status: 001;

Status codes are defined by the Clickatell API.

=item error message

=back

=cut

sub querymsg {
	
	my $idType = undef,
	my $matched = 0;

	my ($self, %data) = @_;
	
	foreach my $key ('apiMsgId', 'cliMsgId') {
		if ( exists $data{$key} && defined $data{$key} ) {
			$matched = 1;
			$idType = $key;
		}
	}
	
	if ( !$matched ) {
		return "ERROR: Either 'apiMsgId' or 'cliMsgId' must be defined";
	}
	printf STDERR "querymsg %s=%s... ", $idType, $data{$idType} if $VERBOSE;

	my $response = $self->{'_som'}->call( querymsg =>
			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
			SOAP::Data->name( $idType   => $data{$idType} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 querymsg()

Query the status of a message.

=head3 Usage

$resp = $hSMS->querymsg( apiMsgId => $apiMsgId );

=over

=item apiMsgId

API message id (apiMsgId) returned by the gateway after a message was sent.

=back

=head3 Returns

=over

=item apiMsgId: followed by message status

eg. apiMsgId: 18e8221e5aa50cfad72376e08f40388a charge: 0.33 status: 004; 

Status codes are defined by the Clickatell API.

=item error message

=back

=cut

sub getmsgcharge {
	
	my ($self, %data) = @_;
	
	if ( !exists $data{'apiMsgId'} || !defined $data{'apiMsgId'} ) {
		return "ERROR: Either 'apiMsgId' or 'cliMsgId' must be defined";
	}
	printf STDERR "querymsg %s=%s... ", 'apiMsgId', $data{'apiMsgId'} if $VERBOSE;

	my $response = $self->{'_som'}->call( getmsgcharge =>
			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
			SOAP::Data->name( 'apiMsgId'  => $data{'apiMsgId'} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 delmsg()

Delete a previously sent message.

=head3 Usage

$resp = $hSMS->delmsg( apiMsgId => $apiMsgId );
$resp = $hSMS->delmsg( cliMsgId => $cliMsgId );

=over

=item apiMsgId

API message id (apiMsgId) returned by the gateway after a message was sent.

=item cliMsgId

client message ID (cliMsgId) you used on submission of the message.

=back

=head3 Returns

=over

=item ID: followed by message status

eg. ID: 18e8221e5aa50cfad72376e08f40388a Status: 001;

Status codes are defined by the Clickatell API.

=item error message

=back

=cut

sub delmsg {
	
	my $idType = undef,
	my $matched = 0;

	my ($self, %data) = @_;
	
	foreach my $key ('apiMsgId', 'cliMsgId') {
		if ( exists $data{$key} && defined $data{$key} ) {
			$matched = 1;
			$idType = $key;
		}
	}
	
	if ( !$matched ) {
		return "ERROR: Either 'apiMsgId' or 'cliMsgId' must be defined";
	}
	printf STDERR "delmsg %s=%s... ", $idType, $data{$idType} if $VERBOSE;

	my $response = $self->{'_som'}->call( delmsg =>
			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
			SOAP::Data->name( $idType   => $data{$idType} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}

###############################################################################

=head2 sendmsg()

Chck the coverage of a network or number without sending a message. If item_user
is supplied, then preexisting session authentication (if any) will be ignored
and the item_user, item_pasword and api_id values will be used to authenticate
this call. This allows you to send a message even if the existing session has
dropped for any reason.

The default (no item_user supplied) is to use the established session.

=head3 Usage

$resp = $hSMS->sendmsg(to => '19991234567', text => 'Hello there...');
$resp = $hSMS->sendmsg(to => @phoneNumbers, text => 'Hello there...');

=over

=item to (required)

A phone number or list of phone numbers to recieve the messsage

=item text (required)

The text of the message to be sent

=item api_id (not implemented yet)

=item user (not implemented yet)

=item password (not implemented yet)

=item from (not implemented yet)

=item concat (not implemented yet)

=item deliv_ack (not implemented yet)

=item callback (not implemented yet)

=item deliv_time (not implemented yet)

=item max_credits (not implemented yet)

=item req_feat (not implemented yet)

=item queue (not implemented yet)

=item escalate (not implemented yet)

=item mo (not implemented yet)

=item cliMsgId (not implemented yet)

=item unicode (not implemented yet)

=item msg_type (not implemented yet)

=item udh (not implemented yet)

=item data (not implemented yet)

=item validity (not implemented yet)

=back

=head3 Returns

=over

=item ID: followed by message id

eg. ID: 18e8221e5aa50cfad72376e08f40388a;

Status codes are defined by the Clickatell API.

=item ERR: followed by an error message

e.g. ERR: 105, Invalid Destination Address;

=back

=cut

#TODO Add more than the basic parameters to sendmsg
sub sendmsg {
	
	my ($authText, $authData, @dest);
	
	my ($self, %data) = @_;
	
	## Figure out what authentication scheme is to be used
	if ( defined $data{'item user'} && exists $data{'item user'} && length($data{'item user'}) > 0 ) {
		$authText = 'as user ' . $data{'item user'};
		$authData = ( 
			SOAP::Data->name( 'api_id' => $data{'api_id'} ),
			SOAP::Data->name( 'item user' => $data{'item user'} ),
			SOAP::Data->name( 'item password' => $data{'item password'} ));
	} else {
		$authText = 'on session ' . $self->{'_session_id'};
		$authData = SOAP::Data->name( 'session_id' => $self->{'_session_id'} );
	}
	
	## Verify that the destination number(s) are in an array
	if ( ref($data{'to'}) eq 'ARRAY' ) {
		@dest = $data{'to'};
	} else {
		push( @dest, $data{'to'} );
	}
	
	printf STDERR "sendmsg to %s %s... ", $data{'to'}, $authText if $VERBOSE;

	my $response = $self->{'_som'}->call( sendmsg =>
			$authData,
#			SOAP::Data->name( 'session_id' => $self->{'_session_id'} ),
#			SOAP::Data->name( 'api_id' => $data{'api_id'} ),
#			SOAP::Data->name( 'item user' => $data{'item user'} ),
#			SOAP::Data->name( 'item password' => $data{'item password'} ),
			SOAP::Data->name( 'to' => @dest ),
			SOAP::Data->name( 'from' => $data{'from'} ),
			SOAP::Data->name( 'text' => $data{'text'} ),
			SOAP::Data->name( 'concat' => $data{'concat'} ),
			SOAP::Data->name( 'deliv_ack' => $data{'deliv_ack'} ),
			SOAP::Data->name( 'callback' => $data{'callback'} ),
			SOAP::Data->name( 'deliv_time' => $data{'deliv_time'} ),
			SOAP::Data->name( 'max_credits' => $data{'max_credits'} ),
			SOAP::Data->name( 'req_feat' => $data{'req_feat'} ),
			SOAP::Data->name( 'queue' => $data{'queue'} ),
			SOAP::Data->name( 'escalate' => $data{'escalate'} ),
			SOAP::Data->name( 'mo' => $data{'mo'} ),
			SOAP::Data->name( 'cliMsgId' => $data{'cliMsgId'} ),
			SOAP::Data->name( 'unicode' => $data{'unicode'} ),
			SOAP::Data->name( 'msg_type' => $data{'msg_type'} ),
			SOAP::Data->name( 'udh' => $data{'udh'} ),
			SOAP::Data->name( 'data' => $data{'data'} ),
			SOAP::Data->name( 'validity' => $data{'validity'} ),
	);

	my $rc = checkResult($self, $response);
	printf STDERR "%s\n", $rc if $VERBOSE;
	return $rc;

}



###############################################################################
## End of package
###############################################################################

1;

__END__

=head1 SEE ALSO

SOAP::Lite, Clickatell SOAP API Specification V 1.1.8

=head1 AUTHOR

Peter Farr <peter.farr@lpi-solutions.com>

=head1 COPYRIGHT AND LICENSE

This software is supplied as is with no warranty. The software is licensed under the terms of
the Creative Commons Attribution 3.0 Unported license
(http://creativecommons.org/licenses/by/3.0/deed.en_CA).

Copyright Peter Farr, 2010.

This module is part of SMS::Clickatell

=cut
