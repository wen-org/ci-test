#!/bin/bash

cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
set -ex

PROJECT_VERSION=$1

# reinstall product
# rm -rf ~/product
# git clone https://pygraphsql:4c03a1c5e1627d80976d57eef0bfd856120437c2@github.com/tigergraph/product.git ~/product
# cd ~/product
# ./gworkspace.sh -x https qa-tigergraph 5d823fd1a69ae41d72244b92d9890ba98d2bb863
# cd -

# change user directory
sudo rm /home/graphsql || true
sudo mv /home/graphsql /home/tigergraph
sudo ln -s /home/tigergraph /home/graphsql
sudo chown -R graphsql:graphsql /home/graphsql

bash $cwd/reinstall.sh

cd ~/product/bigtest/jenkins_script/shell_script
bash install_pkg.sh
