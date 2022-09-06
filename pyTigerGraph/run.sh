#!/bin/bash

set -e 

if [ -z "$1" ]; then
    echo "Please provide setup, clean, or the path to the pyTigerGraph package"
    exit 1;
else
    if [[ "$1" == "clean" ]]; then
        echo "---- Clean up ----"
        docker-compose down
        exit 0
    fi
    pytg_path=$1
fi

if [ -z "$2" ]; then
    if [[ "$pytg_path" != "setup" ]]; then
        echo "Which scripts do you want to run?"
        exit 1;
    fi
else
    shift
    scripts="$@"
fi

echo "---- Starting services ----"
docker-compose up -d kafka tigergraph

echo "---- Waiting for database ----"
fifo=/tmp/tmpfifo.$$
mkfifo "${fifo}" || exit 1
docker logs -f tigergraph >${fifo} &
tailpid=$! # optional
grep -q "Database started" "${fifo}"
kill "${tailpid}" # optional
rm "${fifo}"
echo "Database started"
sleep 10
./mlwb activate http://127.0.0.1

if [[ "$pytg_path" != "setup" ]]; then
    echo "---- Starting test ----"
    docker run --rm --name python --network pytigergraph_default -v ${pytg_path}:/opt/mlwb/package tigergraphml/qa-python:3.9-pytorch-cpu $scripts
fi