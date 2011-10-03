#!/usr/bin/env perl
use warnings;
use strict;

use Mojo::UserAgent;
use Data::Dump qw(dump);

use lib 'common/mojo/lib';

my ( $from, $to ) = @ARGV;

die "usage: $0 http://from/data/database/ http://to/data/database/\n"
unless $from && $to;

my $client = Mojo::UserAgent->new;

my $got = $client->get( $from )->res->json;
warn "# from $from ",dump($got);

my $database = $got->{name};
my $entities = $got->{entities};

sub _url_entity {
	my ($url,$entity) = @_;
	$url =~ s{/?$}{/}; # add slash at end
	$url .= $entity;
	warn "URL $url\n";
	return $url;
}

if ( $database && $entities ) {
	foreach my $entity ( keys %$entities ) {
		my $all = $client->get( _url_entity( $from => $entity ) )->res->json;
		warn "## all = ",dump($all);
		warn "# fetched ", $#$all + 1, " $entity entities from $from";
		foreach my $e ( @$all ) {
			delete $e->{_id}; # sanitize data from older implementation
			my $json = Mojo::JSON->new->encode( $e );
			my $response = $client->post( _url_entity( $to => $entity ), $json )->res->body;
			warn "# replicated $entity\n$json\n",dump($response);
		}
	}
}

