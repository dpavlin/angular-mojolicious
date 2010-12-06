sub filter {
	my $change = shift;
	return 1 if $change->{doc}->{person}->{email};
}

sub trigger {
	my $change = shift;
	warn "# send_email ",dump($change->{doc}->{person});
	$change->{doc}->{email_sent}++;
}

1;
