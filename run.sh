#!/bin/sh -x

if [ ! -z "$1" ] ; then
	git pull
	git submodule init
	git submodule update
	test -f public/angular/build/angular.js || ( cd public/angular && rake compile )
fi

morbo ./angular-server.pl --listen 'http://*:3001'

