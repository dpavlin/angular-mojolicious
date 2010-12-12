#!/bin/sh -x

if [ ! -z "$1" ] ; then
	git pull
	git submodule init
	git submodule update
	test -f public/angular/build/angular.js || ( cd public/angular && rake compile )
fi

./angular-server.pl daemon --reload --listen 'http://*:3001'

