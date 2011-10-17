#!/usr/bin/env perl

use lib 'common/mojo/lib';

use Mojolicious::Lite;
use Data::Dump qw(dump);
use Time::HiRes;
use Clone qw(clone);
use Mojo::UserAgent;

sub new_uuid { Time::HiRes::time * 100000 }

# based on
# http://docs.getangular.com/REST.Basic
# http://angular.getangular.com/data

my $couchdb = $ENV{COUCHDB} || 'http://localhost:5984';
my $client = Mojo::UserAgent->new;

sub _couchdb_put {
	my ( $url, $data ) = @_;

	$data->{'$entity'} = $1 if $url =~ m{/(\w+)\.\d+/$/};

	my $json = Mojo::JSON->new->encode( $data );

	my $rev;

	warn "# _couchdb_put $url = $json";
	return $client->put( "$couchdb/$url" => $json)->res->json;
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

	my $new = _couchdb_put "/$database/$entity.$id" => $json;
	warn "new: ",dump($new);
	if ( $new->{ok} ) {
		$json->{'_'.$_} = $new->{$_} foreach ( 'rev','id' );
	} else {
		warn "ERROR: ",dump($new);
		$json->{error} = $new;
	}

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

# CouchDB proxy for _design _view

get '/:database/_design/:design/_view/:view' => sub {
	my $self = shift;
	my $url = join('/', $self->param('database'),'_design',$self->param('design'),'_view',$self->param('view') );
	my $param = $self->req->url->query->clone->remove('callback')->to_string;
	$url .= '?' . $param if $param;
	warn "CouchDB proxy $url";
	_render_jsonp( $self, _couchdb_get($url));
};

# static JSON files from public/json/database/entity/json

get '/json' => sub {
	_render_jsonp( shift, [ map { s{public/json/}{}; $_ } glob 'public/json/*' ] );
};

get '/json/:database' => sub {
	my $self = shift;
	my $database = $self->param('database');

	my $status = {
		document_counts => 0,
		name => $database,
	};

	foreach my $path ( glob "public/json/$database/*" ) {
		my @entities = glob "$path/*";
		$path =~ s{public/json/$database/}{};
		$status->{entities}->{$path} = scalar @entities;
		$status->{document_counts}++;
	}

	_render_jsonp( $self, $status );
};

get '/json/:database/:entity' => sub {
	my $self = shift;

	my $database = $self->param('database');
	my $entity   = $self->param('entity');

	my $path = "public/json/$database/$entity";
	die "$path: $!" unless -d $path;

	my $docs;
	foreach my $path ( sort glob "$path/*" ) {
		open(my $fh, '<', $path) || die $!;
		local $/ = undef;
		my $str = <$fh>;
		warn "# $path $str";
		my $data = Mojo::JSON->new->decode( $str );
		$data->{_key} = $1 if $path =~ m{/([^/]+$)};
		push @$docs, $data;
	}

	_render_jsonp( $self, $docs )
};

# app/resevations
use Encode;
use iCal::Parser;

plugin 'proxy';

my $slot_regex = '(\d+)\s*mjesta';

get '/reservations/get/(*url)' => sub {
	my $self = shift;

	my $text = $client->get( 'http://' . $self->param('url') )->res->body;
	warn "# get ", $self->param('url'), dump($text);

	$text = decode( 'utf-8', $text );
	$text =~ s{\\,}{,}gs;
	$text =~ s{\\n}{ }gs;

	my $c = iCal::Parser->new->parse_strings( $text );

#	warn "# iCal::Parser = ",dump($c);

	my $ical = {
		cal => $c->{cals}->[0], # FIXME assume single calendar
	};

	my $e = $c->{events};
	my @events;

	foreach my $yyyy ( sort keys %$e ) {
		foreach my $mm ( sort keys %{ $e->{$yyyy} } ) {
			foreach my $dd ( sort keys %{ $e->{$yyyy}->{$mm} } ) {
				push @events, values %{ $e->{$yyyy}->{$mm}->{$dd} };
			}
		}
	}

	@events = map {
		foreach my $check_slot ( qw(
			DESCRIPTION
			LOCATION
			STATUS
			SUMMARY
		)) {
			next unless exists $_->{$check_slot};
			$_->{slots} = $1 if $_->{$check_slot} =~ m/$slot_regex/is;
		}
		$_->{slots} ||= $1 if $ical->{cal}->{'X-WR-CALDESC'} =~ m/$slot_regex/s;
		$_;
	} @events;

	$ical->{events} = [ sort {
					$a->{DTSTART} cmp $b->{DTSTART}
	} @events ];

	_render_jsonp( $self, $ical );
};

get '/reservations/events/:view_name' => sub {
	my $self = shift;

	my $view = _couchdb_get('/reservations/_design/events/_view/' . $self->param('view_name') . '?group=true');
	my $hash;

	if ( exists $view->{error} ) {
		_couchdb_put "/reservations/_design/events", {
			_id => '_design/events',
			language => 'javascript',
			views => {
				submited => {
					map    => q|
						function(doc) {
							if ( doc.event && doc.event.UID ) emit(doc.event.UID, 1)
						}
					|,
					reduce => q|_sum|,
				}
			}
		};
	}

	_render_jsonp( $self, {} ) unless ref $view->{rows} eq 'ARRAY';

	foreach my $row ( @{ $view->{rows} } ) {
		$hash->{ $row->{key} } = $row->{value};
	}

	$hash ||= {};

	_render_jsonp( $self, $hash );
};

get '/_utils/script/(*url)' => sub { $_[0]->proxy_to( "$couchdb/_utils/script/" . $_[0]->param('url') , with_query_params => 1 ) };

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
