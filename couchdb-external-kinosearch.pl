#!/usr/bin/perl
use warnings;
use strict;

# http://wiki.apache.org/couchdb/ExternalProcesses

use KinoSearch::Search::IndexSearcher;
use JSON;
use Data::Dump qw(dump);

$|=1;

my $searcher = KinoSearch::Search::IndexSearcher->new( 
	index => '/tmp/index' 
);

open(my $log, '>>', '/tmp/couchdb-external-kinosearch.log');

while(<STDIN>) {
	warn "# $_\n";
	my $request = decode_json($_);
	print $log "<<< $_\n"; 

	my $response = {
		code => 200,
#		json => {},
	};

	if ( my $q = $request->{query}->{q} ) {

		my $hits = $searcher->hits( query => $q );

		$response->{json}->{total_hits} = $hits->total_hits;

		while ( my $hit = $hits->next ) {
			push @{ $response->{json}->{hits} }, {
				_id => $hit->{_id},
				_rev => $hit->{_rev},
				score => $hit->get_score,
			};
		}

	} else {
		$response->{json}->{error} = "no query found";
	}

	my $json = encode_json($response);
	print $json, $/;
	print $log ">>> $json\n";
}


__END__
; insert following into /etc/couchdb/local.ini:

[log]
level = debug

[external]
kinosearch = /srv/angular-mojolicious/couchdb-external-kinosearch.pl

[httpd_db_handlers]
_kinosearch = {couch_httpd_external, handle_external_req, <<"kinosearch">>}

