#!/bin/bash

cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
set -ex

PROJECT_VERSION=$1
iumBranch='master'
if [[ $# -ge 2 ]]; then
  iumBranch=$2
fi

#LICENSE=`curl -s ftp://ftp.graphsql.com/lic/license.txt`
#~/.gium/gadmin set-license-key $LICENSE || true

kill_legacy_processes(){
  services=('tg_infr_admind' 'tg_infr_dictd' 'tg_dbs_gped' 'tg_dbs_restd' 'tg_dbs_gsed' \
            '\-Dzookeeper.log.dir=.*zk/bin/../conf/zoo.cfg' '\-Dkafka.logs.dir.*kafka/bin' \
            'tg_dbs_gsqld' 'tg_dbs_gsqld.jar' 'tmp_gsql.jar' 'server/src/index.js' 'glive_agent.py' \
            'glive/rest-server/app.js' 'glive/rest-server/loadKafkaData.js' 'nginx')
  for i in "${!services[@]}"; do
    service="${services[$i]}"
    server_pid=$(ps -ef | grep -v grep | grep $service | awk '{print $2}')
    if [[ ! -z "$server_pid" ]]; then
      sudo pkill -TERM -P $server_pids || true
      sudo kill -9 $server_pid || true
      sudo pkill -g $server_pids || true
    fi
  done
}

# stop all service
#gadmin stop -vy || true
#gadmin stop glive -vy || true
#gadmin stop admin -vy || true
#gadmin stop nginx -vy || true
crontab -l | grep -v "admin_crontab" | crontab - || true
sudo killall -9 -r admin_crontab.sh || true
sleep 5
kill_legacy_processes
sleep 5

# delete folder
sudo rm -rf ~/graphsql || true
sudo rm -rf ~/tigergraph || true
sudo rm -rf ~/.gium || true
sudo rm -rf ~/.gsql* || true
sudo rm -rf ~/gium || true
sudo rm -rf ~/.venv || true

base_dir=~

#add IUM
TOKEN='5D4F3079B50C3C25AD015EF68FBA7B20B46B714D'
GIT_TOKEN=$(echo $TOKEN |tr '97531' '13579' |tr 'FEDCBA' 'abcdef')
curl --fail -H "Authorization: token $GIT_TOKEN" -L \
    https://api.github.com/repos/${PROJECT_VERSION}/gium/tarball/$iumBranch -o $base_dir/gium.tar.gz
if [ $? != 0 ]; then
  echo "Download IUM failed"
  exit 1
fi
rm -rf $base_dir/GraphSQL-gium*
rm -rf $base_dir/tigergraph-gium*
tar xzf $base_dir/gium.tar.gz -C $base_dir
if [ $? != 0 ]; then
  echo "Uncompress IUM failed"
  exit 1
fi
if [ "$PROJECT_VERSION" != "TigerGraph" ]; then
  cd $base_dir/GraphSQL-gium*
else
  cd $base_dir/tigergraph-gium*
fi
bash install.sh
cd -
rm -rf $base_dir/GraphSQL-gium*
rm -rf $base_dir/tigergraph-gium*

# config gadmin
if [ "$PROJECT_VERSION" != "TigerGraph" ]; then
  PROJECT_ROOT=/home/graphsql/graphsql
else
  PROJECT_ROOT=/home/tigergraph/tigergraph
fi

LICENSE=`curl -s ftp://ftp.graphsql.com/lic/license.txt`
~/.gium/gadmin set-license-key $LICENSE || true

~/.gium/gadmin --set tigergraph.root.dir $PROJECT_ROOT
~/.gium/gadmin --set tigergraph.storage $PROJECT_ROOT/gstore > /dev/null
~/.gium/gadmin --set gdev.path $PROJECT_ROOT/dev > /dev/null
~/.gium/gadmin --set package.pool $PROJECT_ROOT/pkg_pool > /dev/null
~/.gium/gadmin --set tigergraph.log.root $PROJECT_ROOT/logs > /dev/null
~/.gium/gadmin --set zk.dir $PROJECT_ROOT/zk > /dev/null
~/.gium/gadmin --set kafka.dir $PROJECT_ROOT/kafka > /dev/null
~/.gium/gadmin --set restpp.backup.dir $PROJECT_ROOT/gstore/restpp_backup
~/.gium/gadmin --set mysql.port 3306 || true

LICENSE=`curl -s ftp://ftp.graphsql.com/lic/license.txt`
~/.gium/gadmin set-license-key $LICENSE
