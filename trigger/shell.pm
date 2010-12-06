sub filter {
	my $change = shift;
	return 1 if $change->{doc}->{trigger}->{command};
}


sub trigger {
	my $change = shift;
	my $trigger = $change->{doc}->{trigger};
	if ( my $command = $trigger->{command} ) {
		# FIXME SECURITY HOLE
		my $output = $trigger->{output} = `$command`;

		$trigger->{output} =
			[ map { [ split (/\s+/,$_) ] } split(/\n/,$output) ]
			if $trigger->{format} =~ m/table/i;
	}
}

1;
