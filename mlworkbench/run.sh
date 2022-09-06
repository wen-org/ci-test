#!/bin/bash

set -e 

if [[ "$1" == "clean" ]]; then
    echo "---- Clean up ----"
    docker-compose down
    exit 0
fi

echo "---- Starting services ----"
docker-compose up -d

docker logs -f mlworkbench
