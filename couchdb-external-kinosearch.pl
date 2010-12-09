#!/usr/bin/perl
use warnings;
use strict;

# http://wiki.apache.org/couchdb/ExternalProcesses
#
# curl 'http://localhost:5984/drzb2011/_kinosearch?q=a&include_docs=true'

use KinoSearch::Search::IndexSearcher;
use Mojo::JSON;
use Data::Dump qw(dump);

$|=1;

our $json = Mojo::JSON->new;

open(my $log, '>>', '/tmp/couchdb-external-kinosearch.log');

while(<STDIN>) {
	warn "# $_\n";
	my $request = $json->decode($_);
	print $log "<<< $_\n"; 

	my $response = {
		code => 200,
#		json => {},
	};

	if ( my $q = $request->{query}->{q} ) {

		my $searcher = KinoSearch::Search::IndexSearcher->new( 
			index => '/tmp/kinosearch.' . $request->{info}->{db_name},
		);

		my $hits = $searcher->hits( query => $q );

		$response->{json}->{total_hits} = $hits->total_hits;

		while ( my $hit = $hits->next ) {
			my $r = {
				_id => $hit->{_id},
				_rev => $hit->{_rev},
				score => $hit->get_score,
			};
			$r->{doc} = $json->decode( $hit->{doc} ) if exists $request->{query}->{include_docs};
			push @{ $response->{json}->{hits} }, $r;
		}

	} else {
		$response->{json}->{error} = "no query found";
	}

	my $send = $json->encode($response);
	print $send, $/;
	print $log ">>> $send\n";
}


__END__
; insert following into /etc/couchdb/local.ini:

[log]
level = debug

[external]
kinosearch = /srv/angular-mojolicious/couchdb-external-kinosearch.pl

[httpd_db_handlers]
_kinosearch = {couch_httpd_external, handle_external_req, <<"kinosearch">>}

