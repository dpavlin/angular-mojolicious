#!/usr/bin/env perl

use Mojolicious::Lite;
use Data::Dump qw(dump);

# based on
# http://docs.getangular.com/REST.Basic
# http://angular.getangular.com/data

our $data;
our $id2nr;

get '/' => 'index';

get '/_replicate' => sub {
	my $self = shift;

	if ( my $from = $self->param('from') ) {
		my $got = $self->client->get( $from )->res->json;
		warn "# from $from ",dump($got);
		$self->render_json( $got );

		my $database = $got->{name};
		my $entities = $got->{entities};

		if ( $database && $entities ) {
			foreach my $entity ( keys %$entities ) {
				my $url = $from;
				$url =~ s{/+$}{/};
				$url .= $entity;
				my $e = $self->client->get( $url )->res->json;
				warn "# replicated $url ", dump($e);
				$data->{$database}->{$entity} = $e;
				delete $id2nr->{$database}->{$entity};
			}
		}
	}
};

get '/_data' => sub {
	shift->render_json( $data )
};

get '/data/' => sub {
	my $self = shift;
	$self->render_json( [ keys %$data ] );
};

get '/data/:database' => sub {
	my $self = shift;
	my $database = $self->param('database');
	my $list_databases = { name => $database };
	foreach my $entity ( keys %{ $data->{ $database }} ) {
warn "# entry $entity ", dump( $data->{$database}->{$entity} );
		my $count = $#{ $data->{$database}->{$entity} } + 1;
		$list_databases->{entities}->{$entity} = $count;
		$list_databases->{document_count} += $count;
	}
	warn dump($list_databases);
	$self->render_json( $list_databases );
};

get '/data/:database/:entity' => sub {
	my $self = shift;
	$self->render_json( $data->{ $self->param('database') }->{ $self->param('entity' ) } );
};

get '/data/:database/:entity/:id' => sub {
    my $self = shift;

	my $database = $self->param('database');
	my $entity   = $self->param('entity');
	my $id       = $self->param('id');

	my $e = $data->{$database}->{$entity} || die "no entity $entity";

	if ( ! defined $id2nr->{$database}->{$entity}  ) {
		foreach my $i ( 0 .. $#$e ) {
			$id2nr->{$database}->{$entity}->{ $e->[$i]->{'$id'} } = $i;
		}
	}

	if ( exists $id2nr->{$database}->{$entity}->{$id} ) {
		my $nr = $id2nr->{$database}->{$entity}->{$id};
		warn "# entity $id -> $nr\n";
		$self->render_json( $data->{$database}->{$entity}->[$nr] );
	} else {
		die "no entity $entity $id in ", dump( $id2nr->{$database}->{$entity} );
	}
};

any [ 'put' ] => '/data/:database/:entity/:id' => sub {
	my $self = shift;
	$data->{ $self->param('database') }->{ $self->param('entity') }->{ $self->param('id') } = $self->req->json;
	dumper $data;
};

get '/demo/:groovy' => sub {
	my $self = shift;
    $self->render(text => $self->param('groovy'), layout => 'funky');
};


app->start;
__DATA__

@@ index.html.ep
% layout 'funky';
Yea baby!

@@ layouts/funky.html.ep
<!doctype html><html>
    <head><title>Funky!</title></head>
    <body><%== content %></body>
</html>
