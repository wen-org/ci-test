#!/bin/bash
#
# read input config file, and setup gadmin
# configurs for the cluster
#

cd "$(dirname $0)"
BASE_DIR=$(pwd)

input_config=$1
input_config=${input_config:-$BASE_DIR/cluster_config.json}
output_config=$BASE_DIR/cluster.config

read_config_file(){
  # read cluster_config.json
  python $BASE_DIR/read_config.py $input_config $output_config
  if [ "$?" != 0 ]; then
    echo "Read config file failed"
    exit 1
  fi
  source $output_config
  GSQL_USER=$tigergraph_user_name
  GSQL_USER_PWD=$tigergraph_user_password
  GSQL_ROOT_DIR=$tigergraph_root_dir
  GSQL_LIC_KEY=$license_key

  # get all ip info
  all_nodes_ip=""
  IFS=','
  local login_info=""
  local var=""
  for m in $all_nodes; do
    var="$m"
    login_info="${!var}"
    local ip=$(echo "$login_info" | awk '{print $1}')
    if [ -z "$all_nodes_ip" ]; then
      all_nodes_ip="$m:$ip"
    else
      all_nodes_ip="$all_nodes_ip,$m:$ip"
    fi
  done
  echo "all_nodes_ip: $all_nodes_ip"
  # dict ports number is same as dict servers number
  dict_ports=""
  port=17797
  for m in $zk_server_nodes; do
    if [ -z "$dict_ports" ]; then
      dict_ports="$port"
    else
      dict_ports="$dict_ports,$port"
    fi
    port=$((port + 1))
  done
  echo "dict_ports: $dict_ports"
}

config_sys(){
  local config_file=~/.gsql/gsql.cfg.modified
  if [ ! -f $config_file ]; then
    echo "Cannot find config file: $config_file"
    exit 1
  fi
  sed -i -e "s:^tigergraph.root.dir\: .*$:tigergraph.root.dir\: $GSQL_ROOT_DIR:g" $config_file
  sed -i -e "s:^tigergraph.storage\: .*$:tigergraph.storage\: $GSQL_ROOT_DIR/gstore:g" $config_file
  sed -i -e "s:^gdev.path\: .*$:gdev.path\: $GSQL_ROOT_DIR/dev:g" $config_file
  sed -i -e "s:^package.pool\: .*$:package.pool\: $GSQL_ROOT_DIR/pkg_pool:g" $config_file
  sed -i -e "s:^tigergraph.log.root\: .*$:tigergraph.log.root\: $GSQL_ROOT_DIR/logs:g" $config_file
  sed -i -e "s:^zk.dir\: .*$:zk.dir\: $GSQL_ROOT_DIR/zk:g" $config_file
  sed -i -e "s:^kafka.dir\: .*$:kafka.dir\: $GSQL_ROOT_DIR/kafka:g" $config_file
  sed -i -e "s:^gstudio.data_folder\: .*$:gstudio.data_folder\: $GSQL_ROOT_DIR/loadingData:g" $config_file
  sed -i -e "s:^restpp.backup.dir\: .*$:restpp.backup.dir\: $GSQL_ROOT_DIR/restpp_backup:g" $config_file

  sed -i -e "s/^cluster.nodes: .*$/cluster.nodes: $all_nodes_ip/g" $config_file
  sed -i -e "s/^gpe.servers: .*$/gpe.servers: $gpe_server_nodes/g" $config_file
  sed -i -e "s/^gse.servers: .*$/gse.servers: $gse_server_nodes/g" $config_file
  sed -i -e "s/^restpp.servers: .*$/restpp.servers: $restpp_server_nodes/g" $config_file
  sed -i -e "s/^kafka.servers: .*$/kafka.servers: $kafka_server_nodes/g" $config_file
  sed -i -e "s/^zk.servers: .*$/zk.servers: $zk_server_nodes/g" $config_file
  sed -i -e "s/^gpe.replicas: .*$/gpe.replicas: $gpe_server_replicas/g" $config_file
  sed -i -e "s/^gse.replicas: .*$/gse.replicas: $gse_server_replicas/g" $config_file

  # by default, set dictserver.servers to be same as zk.servers
  sed -i -e "s/^dictserver.servers: .*$/dictserver.servers: $zk_server_nodes/g" $config_file
  sed -i -e "s/^dictserver.base_ports: .*$/dictserver.base_ports: '$dict_ports'/g" $config_file
  # by default, set dictserver.servers, kafka-loader.servers, restpp-loader.servers on all nodes
  sed -i -e "s/^kafka-loader.servers: .*$/kafka-loader.servers: $all_nodes/g" $config_file
  sed -i -e "s/^restpp-loader.servers: .*$/restpp-loader.servers: $all_nodes/g" $config_file
}

set -x

echo "Read config from $input_config"
read_config_file

~/.gium/gadmin --set license.key $GSQL_LIC_KEY
if [ "$?" != 0 ]; then
  echo "Setup license key failed"
  exit 1
fi

echo "gadmin config the cluster ..."
config_sys

echo "Finished gadmin config the cluster!"
