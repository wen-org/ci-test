#!/bin/bash

# uninstall platform of all nodes on the cluster
# provided by cluster_config.json or input config file

cd "$(dirname $0)"
BASE_DIR=$(pwd)

input_config=$1
input_config=${input_config:-$BASE_DIR/cluster_config.json}
output_config=$BASE_DIR/uninstall_cluster.config

read_config_file(){
  # read cluster_config.json
  python $BASE_DIR/read_config.py $input_config $output_config
  if [ "$?" != 0 ]; then
    echo "Read config file failed"
    exit 1
  else
    echo "Config obtained:"
    cat $output_config
  fi
  source $output_config
  GSQL_USER=$tigergraph_user_name
  GSQL_USER_PWD=$tigergraph_user_password
}

uninstall_all(){
  IFS=','
  local login_info=""
  local var=""
  for m in $all_nodes; do
    var="$m"
    login_info="${!var}"
    local ip=$(echo "$login_info" | awk '{print $1}')
    #local option="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    echo "Uninstall platform on node $m ..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $BASE_DIR/uninstall_one_node.sh $GSQL_USER@$ip:~/
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -n $GSQL_USER@$ip "bash ~/uninstall_one_node.sh"
  done
}

set -x

echo "Read config from $input_config"
read_config_file

echo "Uninstalling platform of all nodes on the cluster ..."
uninstall_all

echo "Finished uninstall platform on the cluster!"
