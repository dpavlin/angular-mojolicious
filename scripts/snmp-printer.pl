#!/usr/bin/perl
use warnings;
use strict;

# pull info from SNMP enabled printers and dump JSON

use SNMP::Multi;
use Data::Dump qw(dump);

my $dir = 'public/json/monitor/printers';

use JSON;
sub save_json {
	my ( $ip, $json ) = @_;
	my $path = "$dir/$ip";
	open(my $fh, '>', $path) || die "$path: $!";
	print $fh encode_json $json;
	close($fh);
	warn "# $path ", -s $path, " bytes\n";
}

my $debug = $ENV{DEBUG} || 0; 

my $community = 'public';
my @printers = qw(
10.60.0.20

10.60.3.15
10.60.3.17

10.60.3.19
10.60.3.21

10.60.3.23
10.60.3.25

10.60.3.27
10.60.3.29

10.60.3.31
10.60.3.33

10.60.3.35
10.60.3.37
);

@printers = @ARGV if @ARGV;

# remove final .1 since we are using bulkwalk to get values!
my %vars = qw[
info				iso.3.6.1.2.1.1.1.0
hostname			iso.3.6.1.2.1.43.5.1.1.16.1
serial				iso.3.6.1.2.1.43.5.1.1.17.1
pages				iso.3.6.1.2.1.43.10.2.1.4.1
@message			iso.3.6.1.2.1.43.18.1.1.8
@consumable_name	iso.3.6.1.2.1.43.11.1.1.6.1
@consumable_max		iso.3.6.1.2.1.43.11.1.1.8.1
@consumable_curr	iso.3.6.1.2.1.43.11.1.1.9.1
@tray_max			iso.3.6.1.2.1.43.8.2.1.9.1
@tray_capacity		iso.3.6.1.2.1.43.8.2.1.10.1
@tray_name			iso.3.6.1.2.1.43.8.2.1.13.1
@tray_dim_x			iso.3.6.1.2.1.43.8.2.1.4.1
@tray_dim_y			iso.3.6.1.2.1.43.8.2.1.5.1
];

my $oid2name;
my @vars;
while ( my ($name,$oid) = each %vars ) {
	$oid =~ s/\.[0-1]$// if $name !~ /^\@/;
	push @vars, [ $oid ];
	$oid2name->{$oid} = $name;
}
my @oids = sort { length $a <=> length $b } keys %$oid2name;
warn "# vars = ",dump(@vars) if $debug;

my $sm = SNMP::Multi->new(
	Method    => 'bulkwalk',
	Community => $community,
	Requests  => SNMP::Multi::VarReq->new(
		hosts => [ @printers ],
		vars  => [ @vars ],
    ),
	Timeout     => 1,
	Retries     => 0,
) or die $SNMP::Multi::error;

warn "# working on: ", join(' ', @printers),$/;

my $resp = $sm->execute() or die $sm->error();

my $collected;

foreach my $host ( $resp->hosts ) {
	my $status;

	foreach my $result ( $host->results ) {
		if ( $result->error ) {
			warn "ERROR: $host ", $result->error;
			next;
		}

		warn "## result = ", dump($result) if $debug;

		foreach my $v ( $result->varlists ) {
			foreach my $i ( @$v ) {
				my ( $oid, undef, $val, $fmt ) = @$i;
				if ( my $name = $oid2name->{$oid} ) {
					$status->{$name} = $val;
				} else {
					my $oid_base;
					foreach ( @oids ) {
						my $oid_part = substr($oid,0,length($_));
						if ( $oid_part eq $_ ) {
							$oid_base = $oid_part;
							last;
						}
					}

					my $name = $oid2name->{$oid_base} || die "no name for $oid in ",dump( $oid2name );
					if ( $name =~ s/^\@// ) {
						push @{ $status->{$name} }, $val;
					} else {
						$status->{$name} = $val;
					}
				}
			}
		}

	}

	foreach my $group ( grep { /\w+_\w+/ } keys %$status ) {
		my ( $prefix,$name ) = split(/_/,$group,2);
		foreach my $i ( 0 .. $#{ $status->{$group} } ) {
			$status->{$prefix}->[$i]->{$name} = $status->{$group}->[$i];
		}
		delete $status->{$group};
	}

	print "$host = ",dump($status);
	save_json $host => $status;
	$collected->{$host} = $status;
}

