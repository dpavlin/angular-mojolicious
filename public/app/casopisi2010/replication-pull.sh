#!/bin/sh -x

curl -v -X POST localhost:5984/_replicate -d '{"source":"http://10.60.0.95:5984/casopisi2010","target":"casopisi2010","continuous":true}'
