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
$schema->spec_field( name => '_id',   type => $type );
$schema->spec_field( name => '_rev', type => $type );

# Create the index and add documents.
our $indexer;


sub _indexer {
	$indexer ||= KinoSearch::Index::Indexer->new(
		schema => $schema,   
		index  => '/tmp/index',
		create => 1,
	);
};

use JSON;

sub flatten {
	my ($flat,$data,$prefix) = @_;
	if ( ref $data eq '' ) {
		$$flat->{$prefix} = $data;
	} elsif ( ref $data eq 'HASH' ) {
		foreach my $key ( keys %$data ) {
			my $full_prefix = $prefix ? $prefix . '.' : '';
			$full_prefix .= $key;
			flatten( $flat, $data->{$key}, $full_prefix );
		}
	} elsif ( ref $data eq 'ARRAY' ) {
		$$flat->{$prefix} = join("\n", map { ref $_ ? dump($_) : $_ } @$data);
		# FIXME arrays with non-scalar references aren't really indexed well
	}
}

sub filter {
	my $change = shift;
	my $doc = $change->{doc} || next;
	my $flat;
	flatten( \$flat, $doc, '' );
	foreach my $field ( keys %$flat ) {
		next if $schema->fetch_type($field);
		$schema->spec_field( name => $field, type => $type );
		warn "# +++ $field\n";
	}
	warn "# add_doc ",dump($flat);
	_indexer->add_doc($flat);
	return 0;
}

sub commit {
	$indexer->commit;
	undef $indexer;
	warn "# commit index done";
}

1;
