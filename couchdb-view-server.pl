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

open(my $l_fh, '>', "/tmp/couchdb-perl-view.log");

sub _log {
	$out->print($j->encode([ 'log' => @_ ]), "\n");
	print $l_fh "@_\n";
}

our $fun;

while(defined(my $line = $in->getline)) {
	chomp $line;
	_log $line if $ENV{DEBUG};
	my $input = $j->decode($line);
	my ($cmd, @args) = @$input;

	if ( $cmd eq 'reset' ) {
		undef $fun;
		$out->print("true\n");
	} elsif ( $cmd eq 'add_fun' ) {
		$fun = eval $args[0];
		if ( $@ ) {
			$out->print( qq|{"error": "$!", "reason": "$@"}\n| );
		} else {
			$out->print("true\n");
		}
	} elsif ( $cmd eq 'map_doc' ) {
		my @results;
		our $d;
		local $d;
		$d = eval { $fun->(@args) };
		if ( $@ ) {
			_log $@;
		} else {
			push @results, [$d];
		}
		$out->print($j->utf8->encode( \@results ), "\n");
	} else {
		_log "$cmd unimplemented", dump( $input );
	}
}
