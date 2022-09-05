#!/bin/bash

set -e 

if [[ -f "/opt/mlwb/package/setup.py" ]]; then
    cd /opt/mlwb/package/
    pip3 install --disable-pip-version-check -q .
    cd /opt/mlwb
else
    export PYTHONPATH=/opt/mlwb/package
    cd /opt/mlwb/package
fi


for script in "$@"
do
    echo "----------------------------------------------------------------------"
    echo "Running $script"
    python3 $script
done
