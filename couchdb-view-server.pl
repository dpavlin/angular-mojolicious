#!/usr/bin/perl
use warnings;
use strict;

# http://wiki.apache.org/couchdb/View_server

use JSON::XS;
use IO::Handle;
use Data::Dump qw(dump);

my $j = JSON::XS->new;

my $in  = IO::Handle->new_from_fd(\*STDIN, 'r');
my $out = IO::Handle->new_from_fd(\*STDOUT, 'w');
$out->autoflush(1);

sub _log {
	$out->print(qq|["log", "@_"]\n|);
	warn "# log @_\n";
}

our $fun;

while(defined(my $line = $in->getline)) {
	chomp $line;
	my $input = $j->decode($line);
	my ($cmd, @args) = @$input;

	if ( $cmd eq 'reset' ) {
		undef $fun;
		$out->print("true\n");
	} elsif ( $cmd eq 'add_fun' ) {
		$fun = eval @args;
		if ( $@ ) {
			$out->print( qq|{"error": "$!", "reason": "$@"}\n| );
		} else {
			$out->print("true\n");
		}
	} elsif ( $cmd eq 'map_doc' ) {
		my @results;
		our @d;
		local @d;
		eval { $fun->(@args) };
		if ( $@ ) {
			_log $@;
		} else {
			push @results, [@d];
		}
		$out->print($j->utf8->encode( \@results ), "\n");
	} else {
		die "$cmd unimplemented", dump( $input );
	}
}
