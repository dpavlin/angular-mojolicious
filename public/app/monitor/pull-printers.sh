#!/bin/sh -x

dir=/srv/angular-mojolicious/public/json/

rsync -rav klin:$dir $dir
