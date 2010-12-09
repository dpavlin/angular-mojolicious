use KinoSearch::Index::Indexer;
use KinoSearch::Plan::Schema;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Plan::FullTextType;

# Create a Schema which defines index fields.
my $schema = KinoSearch::Plan::Schema->new;
my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new( 
	language => 'en',
);
my $type = KinoSearch::Plan::FullTextType->new(
	analyzer => $polyanalyzer,
);
my $blob_type = KinoSearch::Plan::BlobType->new( stored => 1 );
my $string_type = KinoSearch::Plan::StringType->new;
$schema->spec_field( name => '_id',   type => $string_type );
$schema->spec_field( name => '_rev', type => $string_type );
$schema->spec_field( name => 'doc', type => $blob_type );

# Create the index and add documents.
our $indexer;


sub _indexer {
	$indexer ||= KinoSearch::Index::Indexer->new(
		schema => $schema,   
		index  => "/tmp/kinosearch.$database", 
		create => 1,
	);
};

sub flatten {
	my ($flat,$data,$prefix) = @_;
	if ( ref $data eq '' ) {
		$$flat->{$prefix} .= "\n" . $data;
		$$flat->{$prefix} =~ s/^\n//; # strip first
	} elsif ( ref $data eq 'HASH' ) {
		foreach my $key ( keys %$data ) {
			my $full_prefix = $prefix ? $prefix . '.' : '';
			$full_prefix .= $key;
			flatten( $flat, $data->{$key}, $full_prefix );
		}
	} elsif ( ref $data eq 'ARRAY' ) {
		foreach my $el ( @$data ) {
			flatten( $flat, $el, $prefix );
		}
	} elsif ( ref $data eq 'Mojo::JSON::_Bool' ) {
		$$flat->{$prefix} = $data;
	} else {
		die "unsupported ",ref($data)," from ",dump($data);
	}
}

sub filter {
	my $change = shift;
	my $doc = $change->{doc} || next;

	_indexer->delete_by_term( field => '_id', term => $doc->{_id} );
	return 0 if $doc->{_deleted};

	my $flat;
	flatten( \$flat, $doc, '' );
	foreach my $field ( keys %$flat ) {
		next if $schema->fetch_type($field);
		$schema->spec_field( name => $field, type => $type );
		warn "# +++ $field\n";
	}
	$flat->{doc} = $json->encode($doc);
	warn "# add_doc ",dump($flat);
	_indexer->add_doc($flat);
	return 0;
}

sub commit {
	return unless $indexer;
	$indexer->commit;
	undef $indexer;
	warn "# commit index done\n";
}

1;
