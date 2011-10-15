#!/usr/bin/perl
use warnings;
use strict;

# http://wiki.apache.org/couchdb/View_server
#
# /etc/couchdb/local.ini add:
#
# [query_servers]
# perl = /usr/bin/perl /srv/angular-mojolicious/couchdb-view-server.pl
#
# example view:
#
# sub { [ undef, shift ] }

use JSON::XS;
use IO::Handle;
use Data::Dump qw(dump);

my $j = JSON::XS->new;

my $in  = IO::Handle->new_from_fd(\*STDIN, 'r');
my $out = IO::Handle->new_from_fd(\*STDOUT, 'w');
$out->autoflush(1);

open(my $l_fh, '>>', "/tmp/couchdb-perl-view.log");
$l_fh->autoflush(1);

sub _debug {
	print $l_fh "@_\n";
}

sub _log {
	$out->print($j->encode([ 'log' => @_ ]), "\n");
}

our @fun;

while(defined(my $line = $in->getline)) {
	chomp $line;
	_debug $line;
	my $input = $j->decode($line);
	my ($cmd, @args) = @$input;

	if ( $cmd eq 'reset' ) {
		@fun = ();
		$out->print("true\n");
	} elsif ( $cmd eq 'add_fun' ) {
		push @fun, eval $args[0];
		if ( $@ ) {
			$out->print( qq|{"error": "$!", "reason": "$@"}\n| );
		} else {
			$out->print("true\n");
		}
	} elsif ( $cmd eq 'map_doc' ) {
		my @results;
		foreach my $fun ( @fun ) {
			my $d = eval { $fun->(@args) };
			_log $@ if $@;
			push @results, [$d];
		}
		my $json = $j->utf8->encode( \@results );
		$out->print("$json\n");
		_debug "# $json";
	} else {
		_log "$cmd unimplemented", dump( $input );
	}
}
