#!/usr/bin/env perl

use Mojolicious::Lite;
use Data::Dump qw(dump);

# based on
# http://docs.getangular.com/REST.Basic
# http://angular.getangular.com/data

our $data = {
	'Cookbook' => {
		test => [
				{ '$id' => 1, foo => 1, bar => 2, baz => 3 },
				{ '$id' => 2, foo => 1                     },
				{ '$id' => 3,           bar => 2           },
				{ '$id' => 4,                     baz => 3 },
		],
	}
};
our $id2nr;

sub _render_jsonp {
	my ( $self, $json ) = @_;
	my $data = $self->render( json => $json, partial => 1 );
	if ( my $callback = $self->param('callback') ) {
		$data = "$callback($data)";
	}
	$self->render( data => $data, format => 'js' );
}

get '/' => 'index';

get '/_replicate' => sub {
	my $self = shift;

	if ( my $from = $self->param('from') ) {
		my $got = $self->client->get( $from )->res->json;
		warn "# from $from ",dump($got);
		_render_jsonp( $self,  $got );

		my $database = $got->{name};
		my $entities = $got->{entities};

		if ( $database && $entities ) {
			foreach my $entity ( keys %$entities ) {
				my $url = $from;
				$url =~ s{/?$}{/}; # add slash at end
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
	my $self = shift;
	_render_jsonp( $self, $data )
};

get '/data/' => sub {
	my $self = shift;
	_render_jsonp( $self,  [ keys %$data ] );
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
	_render_jsonp( $self,  $list_databases );
};

get '/data/:database/:entity' => sub {
	my $self = shift;
	_render_jsonp( $self,  $data->{ $self->param('database') }->{ $self->param('entity' ) } );
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
		_render_jsonp( $self,  $data->{$database}->{$entity}->[$nr] );
	} else {
		die "no entity $entity $id in ", dump( $id2nr->{$database}->{$entity} );
	}
};

any [ 'put', 'post' ] => '/data/:database/:entity/:id' => sub {
	my $self = shift;
	my $data = $self->req->json;
	warn "# body ",dump($self->req->body, $data);
	die "no data" unless $data;
	$data->{ $self->param('database') }->{ $self->param('entity') }->{ $self->param('id') } = $data;
	_render_jsonp( $self,  $data );
};

get '/demo/:groovy' => sub {
	my $self = shift;
    $self->render(text => $self->param('groovy'), layout => 'funky');
};

get '/Cookbook' => 'Cookbook';
get '/Cookbook/:example' => sub {
	my $self = shift;
	$self->render( "Cookbook/" . $self->param('example'), layout => 'angular' );
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

@@ layouts/angular.html.ep
<!DOCTYPE HTML>
<html xmlns:ng="http://angularjs.org">
  <head>
    <script type="text/javascript"
         src="<%== $ENV{ANGULAR_JS} || '/build/angular.js' %>" ng:autobind></script>
  </head>
  <body><%== content %></body>
</html>
