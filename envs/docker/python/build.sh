#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Which Python version (x.x) do you want?"
    exit 1;
else
    version=$1
fi

if [ -z "$2" ]; then
    echo "Which ml framework do you want, pytorch or tensorflow?"
    exit 1;
else
    framework=$2
fi

if [ -z "$3" ]; then
    echo "Which kind of device do you want, cpu or cuda?"
    exit 1;
else
    device=$3
fi

# Build the image
echo "---- Building image ----"
docker build --build-arg VER=${version} -f ${framework}-${device}.Dockerfile -t qa-python:${version}-${framework}-${device} .

echo "---- Pushing to docker hub ----"
# docker tag qa-python:${version}-${framework}-${device} tigergraphml/qa-python:${version}-${framework}-${device}
# docker push tigergraphml/qa-python:${version}-${framework}-${device}
