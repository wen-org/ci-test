#!/bin/bash
########################################################################################
# setup env
source ${HOME}/.bashrc
export PATH=$PATH:${HOME}/.gium

export PRODUCT=$(cd $(dirname ${BASH_SOURCE[0]})/../../ && pwd)
export BIGTEST_FOLDER="${PRODUCT}/bigtest"
export JENKINS_SCRIPT_FOLDER="${BIGTEST_FOLDER}/jenkins_script"
export SHELL_SCRIPT_FOLDER="${JENKINS_SCRIPT_FOLDER}/shell_script"
export PYTHON_SCRIPT_FOLDER="${JENKINS_SCRIPT_FOLDER}/python_script"
########################################################################################
# function to save and restore zk, kafka, and gsql config folder
export PROJECT_ROOT=`grep tigergraph.root.dir $HOME/.gsql/gsql.cfg | cut -d " " -f 2`
export GSQL_PATH=$(cat $HOME/.gsql/gsql.cfg | grep gdev | cut -d ' ' -f 2)/gdk/gsql
export KAFKA_DIR="${PROJECT_ROOT}/kafka"
export ZK_DIR="${PROJECT_ROOT}/zk"

export GSQL_TEMP_DIR="/tmp/${USER}_tigergraph_temp"
export KAFKA_TEMP_DIR="${GSQL_TEMP_DIR}/kafka"
export ZK_TEMP_DIR="${GSQL_TEMP_DIR}/zk"

export CONFIG_DIR="$HOME/.gsql"
export CONFIG_TEMP_DIR="/tmp/${USER}_gsql_conf_temp"

export GIT_USER=$(jq -r .GIT_USER ${JENKINS_SCRIPT_FOLDER}/config/config.json)
export GIT_TOKEN=$(jq -r .GIT_TOKEN ${JENKINS_SCRIPT_FOLDER}/config/config.json)

function stop_service() {
  gadmin stop admin -vy
  sleep 5
  gadmin stop -vy
  sleep 5
  gadmin stop glive -vy
  sleep 5
  killall -9 tg_infr_admind || true
}

function check_and_move() {
  grun all " 
    if [ -d $1 ]
    then
      rm -rf $2
      mv $1 $2
    fi
  "
}

# save workspace
function save_workspace() {
  stop_service
  # backup zk, kafka folder
  grun all "rm -rf $GSQL_TEMP_DIR"
  grun all "mkdir -p $GSQL_TEMP_DIR"
  grun all "cp -rp $KAFKA_DIR $KAFKA_TEMP_DIR"
  grun all "cp -rp $ZK_DIR $ZK_TEMP_DIR"

  # backup gsql folder
  grun all "rm -rf $CONFIG_TEMP_DIR"
  grun all "cp -rp $CONFIG_DIR $CONFIG_TEMP_DIR"
  gadmin start admin -v
  sleep 10
}

# restore workspace
function restore_workspace() {
  stop_service
  # save pkg info status, needed since we will restore gsql folder
  # which contains old pkg info status
  grun all "cp -p $CONFIG_DIR/fab_dir/logs/status $CONFIG_TEMP_DIR/fab_dir/logs/status"

  # recover zk, kafka folder
  check_and_move $ZK_TEMP_DIR $ZK_DIR
  check_and_move $KAFKA_TEMP_DIR $KAFKA_DIR

  # recover gsql folder
  check_and_move $CONFIG_TEMP_DIR $CONFIG_DIR

  # the order matter here! can not start admin before sync to dict
  gadmin start dict -v
  sleep 10
  gadmin __sync-config-to-dict
  sleep 5
  gadmin start admin -v
  sleep 5
}

# clean up test case leftovers
function clean_up() {
  rm -rf $PROJECT_ROOT/config/endpoints
  rm -rf $PROJECT_ROOT/bin/scheduler.so
  rm -rf /tmp/unittest
  rm -rf /tmp/gsql

  # clean up zk
  $PROJECT_ROOT/zk/bin/zkCli.sh -server 127.0.0.1:19999 <<EOF || true
  rmr /tigergraph/dict/objects/__services/RLS-GSE/_static_nodes
  rmr /tigergraph/dict/objects/__services/RLS-GSE/_expelled_nodes
  quit
EOF
}

########################################################################################
# Functions and variables for address sanitizer
function read_ut_opt(){
  export MODE="release"
  while [[ $# -gt 0 ]]; do
    #if "-db" flag is present set scons compile mode to debug
    if [ $1 = "-db" ]; then
      export MODE="debug"
      shift 1
    #Set options for address sanitizer
    elif [ $1 = "-sanitizer" ]; then
      set_asan_opt $2
      shift 2
    else
      shift 1
    fi
  done
}

function set_asan_opt() {
  SANITIZER_TYPE="addr" # thread
  if [[ $# > 1 && "$1" == "thread" ]]; then
    SANITIZER_TYPE=$1
  fi
  echo 'Setting options for address sanitizer'
  export SAN_COMPILE_OPT=$SANITIZER_TYPE"check=true"
  export ASAN_OPTIONS="disable_coredump=0:unmap_shadow_on_exit=1:abort_on_error=1:symbolize=1"
  export ASAN_SYMBOLIZER_PATH=$(which llvm-symbolizer-3.4)
  export LSAN_OPTIONS="suppressions=${JENKINS_SCRIPT_FOLDER}/config/leak_blocker"
}


########################################################################################
