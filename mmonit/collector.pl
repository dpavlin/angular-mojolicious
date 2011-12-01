#!/usr/bin/env perl
use Mojolicious::Lite;

# Documentation browser under "/perldoc"
#plugin 'PODRenderer';

use Mojo::JSON;
use Mojo::UserAgent;
use Data::Dump qw(dump);
use XML::Simple;
use Time::HiRes;

my $json = Mojo::JSON->new;
my $client = Mojo::UserAgent->new;

post '/collector' => sub {
	my $self = shift;
	my $data = XMLin( $self->req->body );
	warn dump( $data );

	# post will create new dockument, put will insert known key
	my $key = sprintf "%10.5f", Time::HiRes::time;
	my $res = $client->put( "http://localhost:5984/mmonit/$key" => { 'Content-Type' => 'application/json' } => $json->encode( $data ) )->res->json;

	warn "# res = ",dump($res);

	$self->render('index');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to Mojolicious!

@@ layouts/default.html.ep
<!doctype html><html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
