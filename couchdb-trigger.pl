#!/usr/bin/perl

# http://wiki.apache.org/couchdb/HTTP_database_API#Changes

use warnings;
use strict;

use lib 'common/mojo/lib';

use Mojo::Client;
use Mojo::JSON;

my $url = 'http://localhost:5984/monitor';
my $seq = 0;

my $client = Mojo::Client->new;
our $json   = Mojo::JSON->new;
sub info { warn $_[0], " ",$json->encode($_[1]),$/ }
sub debug { info "# $_[0]", $_[1] }
my $error;

$client->keep_alive_timeout(90); # couchdb timeout is 60s

while( ! $error ) {

	my $changes_feed = "$url/_changes?feed=continuous;include_docs=true;since=$seq";
	info 'GET' => $changes_feed;
	my $tx = $client->build_tx( GET => $changes_feed );
	$tx->res->body(sub{
		my ( $content, $body ) = @_;

		debug 'BODY' => $body;

		if ( length($body) == 0 ) {
			warn "# empty chunk, heartbeat?\n";
			return;
		}

		foreach ( split(/\r?\n/, $body) ) { # we can get multiple documents in one chunk

			my $change = $json->decode($_);

			if ( exists $change->{error} ) {
				$error = $change;
			} elsif ( exists $change->{last_seq} ) {
				$seq = $change->{last_seq};
			} elsif ( $change->{seq} <= $seq ) {
				info "ERROR: stale" => $change;
			} elsif ( exists $change->{changes} ) {

				my $id  = $change->{id} || warn "no id?";
				my $rev = $change->{changes}->[0]->{rev} || warn "no rev?";
				   $seq = $change->{seq} || warn "no seq?";

				debug 'change' => $change;

				if ( my $trigger = $change->{doc}->{trigger} ) {
					if ( exists $trigger->{active} ) {
						debug 'trigger.active',  $change->{doc}->{trigger}->{active};
					} else {
						$trigger->{active} = [ time() ];

						debug 'TRIGGER start PUT ', $change->{doc};
						$client->put( "$url/$id" => $json->encode( $change->{doc} ) => sub {
							my ($client,$tx) = @_;
							if ($tx->error) {
								if ( $tx->res->code == 409 ) {
									info "TRIGGER ABORTED started on another worker? ", $tx->error;
								} else {
									info "ERROR ", $tx->error;
								}
							} else {
								my $res = $tx->res->json;
								$change->{doc}->{_rev} = $res->{rev};
								debug "TRIGGER execute ", $change->{doc};

								# FIXME trigger logic?

								push @{ $trigger->{active} }, time(); # timestamp step

								$client->put( "$url/$id" => $json->encode( $change->{doc} ) => sub {
									my ($client,$tx) = @_;
									if ($tx->error) {
										info "ERROR", $tx->error;
									} else {
										my $res = $tx->res->json;
										$change->{doc}->{_rev} = $res->{rev};
										info "TRIGGER finish ", $change->{doc};
									}
								})->process;
							}
						})->process;
					}
				}
			} else {
				warn "UNKNOWN", $json->encode($change);
			}

		}

	});
	$client->start($tx);

}

die "ERROR ", $json->encode($error) if $error;
