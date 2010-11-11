#!/usr/bin/env perl

use lib 'common/mojo/lib';

use Mojolicious::Lite;
use Data::Dump qw(dump);
use Time::HiRes;
use Clone qw(clone);

sub new_uuid { Time::HiRes::time * 100000 }

# based on
# http://docs.getangular.com/REST.Basic
# http://angular.getangular.com/data

my $couchdb = 'http://localhost:5984';
my $client = Mojo::Client->new;

sub _couchdb_put {
	my ( $url, $data ) = @_;

	$data->{'$entity'} = $1 if $url =~ m{/(\w+)\.\d+/$/};

	my $json = Mojo::JSON->new->encode( $data );

	my $rev;

	warn "# _couchdb_put $url = $json";
	$client->put( "$couchdb/$url" => $json => sub {
		my ($client,$tx) = @_;
		my ($message, $code) = $tx->error;
		my $response = $tx->res->json;
		warn "## response $code ",dump($response);
		if ($tx->error) {
			warn "ERROR $code $message";
		}
		return
		$rev = $response->{rev};
	})->process;

	warn "## rev = $rev";
	return $rev;
}

sub _couchdb_get {
	my ( $url ) = @_;
	my $return = $client->get( "$couchdb/$url" )->res->json;
	warn "# _couchdb_get $url = ",dump($return);
	return $return;
}


our $id2nr;


sub _render_jsonp {
	my ( $self, $json ) = @_;
#warn "## _render_json ",dump($json);
	my $data = $self->render( json => $json, partial => 1 );
warn "## _render_json $data";
	if ( my $callback = $self->param('callback') ) {
		$data = "$callback($data)";
	}
	$self->render( data => $data, format => 'js' );
}

#get '/' => 'index';


get '/data/' => sub {
	my $self = shift;
	_render_jsonp( $self, _couchdb_get('/_all_dbs') );
};

get '/data/:database' => sub {
	my $self = shift;
	my $database = $self->param('database');

	my $list_databases = { name => $database };

	my $counts = _couchdb_get("/$database/_design/entity/_view/counts?group=true");
	if ( exists $counts->{error} ) {
		warn "creating CouchDB view because of ", dump($counts);
		_couchdb_put "/$database/_design/entity", {
			_id => '_design/entity',
			language => 'javascript',
			views => {
				counts => {
					map    => q| function(doc) { emit(doc._id.split('.')[0],1); } |,
					reduce => q| function(keys,values,rereduce) { return sum(values); } |,
				}
			}
		};
		$counts = _couchdb_get("/$database/_design/entity/_view/counts?group=true")
		|| die "give up!";
	}

	warn "# counts ",dump($counts);

	foreach my $row ( @{ $counts->{rows} } ) {
		my $n = $row->{value};
		$list_databases->{entities}->{ $row->{key} } = $n;
		$list_databases->{document_counts} += $n;
	}
	warn dump($list_databases);
	_render_jsonp( $self,  $list_databases );
};

get '/data/:database/:entity' => sub {
	my $self = shift;

	my $database = $self->param('database');
	my $entity   = $self->param('entity');

	my $endkey = $entity;
	$endkey++;

	my $counts = _couchdb_get qq|/$database/_all_docs?startkey="$entity";endkey="$endkey";include_docs=true|;
	warn "# counts ",dump($counts);

	_render_jsonp( $self, [ map { $_->{doc} } @{ $counts->{rows} } ] )
};

get '/data/:database/:entity/:id' => sub {
    my $self = shift;

	my $database = $self->param('database');
	my $entity   = $self->param('entity');
	my $id       = $self->param('id');

	_render_jsonp( $self, _couchdb_get( "/$database/$entity.$id" ) );
};

any [ 'post' ] => '/data/:database/:entity' => sub {
	my $self = shift;
	my $database = $self->param('database');
	my $entity   = $self->param('entity');
	my $json = $self->req->json;
	my $id = $json->{'$id'} # XXX we don't get it back from angular.js
		|| new_uuid;
	warn "## $database $entity $id body ",dump($self->req->body, $json);

	$json->{'$id'} ||= $id;	# make sure $id is in there

	my $rev = _couchdb_put "/$database/$entity.$id" => $json;
	$json->{_rev} = $rev;

	_render_jsonp( $self,  $json );
};


get '/' => sub { shift->redirect_to('/Cookbook') };

get '/Cookbook' => 'Cookbook';
get '/Cookbook/:example' => sub {
	my $self = shift;
	$self->render( "Cookbook/" . $self->param('example'), layout => 'angular' );
};

get '/conference/:page' => sub {
	my $self = shift;
	$self->render( "conference/" . $self->param('page'), layout => 'angular' );
};

# /app/

get '/app/:database/angular.js' => sub {
	my $self = shift;
	my $ANGULAR_JS = $ENV{ANGULAR_JS} || ( -e 'public/angular/build/angular.js' ? '/angular/build/angular.js' : '/angular/src/angular-bootstrap.js' );
	warn "# $ANGULAR_JS";
	$self->render_static( $ANGULAR_JS );
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
   <meta charset="utf-8">
% my $ANGULAR_JS = $ENV{ANGULAR_JS} || ( -e 'public/angular/build/angular.js' ? '/angular/build/angular.js' : '/angular/src/angular-bootstrap.js' );
    <script type="text/javascript"
         src="<%== $ANGULAR_JS %>" ng:autobind></script>
  </head>
  <body><%== content %></body>
</html>
