#!/bin/bash
#
# uninstall TigerGraph platform under current user
#

cd `dirname $0`
BASE_DIR=$(pwd)

# services need to be stopped before install platform
services_set=('tg_infr_admind' 'tg_infr_dictd' 'tg_dbs_gped' 'tg_dbs_restd' 'tg_dbs_gsed' \
              '\-Dzookeeper.log.dir=.*zk/bin/../conf/zoo.cfg' '\-Dkafka.logs.dir.*kafka/bin' \
              'tg_dbs_gsqld' 'tg_dbs_gsqld.jar' 'server/src/index.js' 'glive_agent.py' \
              'glive/rest-server/app.js' 'glive/rest-server/loadKafkaData.js' 'tmp_gsql.jar' \
              'bin/nginx/sbin/nginx')

# function to get service pid
# param: service string
# return: service pid
get_service_pids(){
  local service=$1
  local server_pids=$(ps -ef | grep -v grep | grep $service | awk '{print $2}')
  if [ ! -z "$server_pids" ]; then
    echo "$server_pids"
  fi
}

# function to stop old services
# param: NONE
# step 1, stop all services by gadmin
# step 2, remove admin_server cron job
# step 3, kill services in case of step 1 failed (license expired, user removed scripts)
stop_services(){
  echo "Stopping services ..."
  crontab -l | grep -v admin_crontab | crontab -
 # don't use gadmin stop, other nodes may be using in another MIT/WIP job
 # ~/.gium/gadmin stop admin -y || :
 # ~/.gium/gadmin stop -y || :
  for i in "${!services_set[@]}"; do
    service="${services_set[$i]}"
    server_pids=$(get_service_pids $service)
    if [ ! -z "$server_pids" ]; then
      sudo pkill -TERM -P $server_pids &>/dev/null
      sudo kill -9 $server_pids >/dev/null 2>&1
      # nginx master process may start new slave process, need to be killed
      sudo pkill -g $server_pids &>/dev/null
    fi
  done
  sleep 1
}

# function to uninstall platform
# param: NONE
# step 1, stop all services
# step 2, remove .gium, .gsql*, {root.dir}
__uninstall_platform(){
  echo "In function __uninstall_platform ..."
  stop_services
  #root_dir=$(grep root.dir ~/.gsql/gsql.cfg | awk -F': ' '{print $2}')
  root_dir="/home/graphsql/tigergraph"
  rm -rf ~/.gium
  rm -rf ~/.gsql*
  if [[ "$root_dir" =~ "tigergraph"$ ]] || [[ "$root_dir" =~ "graphsql"$ ]]; then
    rm -rf $root_dir
  fi
  sed -i '/.*gsql_admin_complete.*/d' ~/.bashrc
}

__uninstall_platform
