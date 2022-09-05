#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Which database version (x.x.x) do you want?"
    exit 1;
else
    version=$1
fi

# Build the Jupyter Pytorch for CPU 
echo "---- Building image ----"
docker build --build-arg VER=${version} -t qa-db:${version} .

echo "---- Pushing to docker hub ----"
docker tag qa-db:${version} tigergraphml/qa-db:${version}
docker push tigergraphml/qa-db:${version}