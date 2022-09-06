#!/bin/bash
########################################################################################
source $(cd $(dirname ${BASH_SOURCE[0]}) && pwd)/util.sh
set -exo pipefail
########################################################################################
# collect log informations and binaries
function collect_log () {
  if [ -z $LOG_FOLDER ]; then
    LOG_FOLDER="/tmp/${USER}_test/"
    rm -rf $LOG_FOLDER
    mkdir -p $LOG_FOLDER || true
  fi
  $SHELL_SCRIPT_FOLDER/collector.sh $LOG_FOLDER &> $LOG_FOLDER/bigtest_log/collector.log
}

function finally () {
  exit_code=$?
  if [[ $exit_code == 0 ]]; then
    echo "Success!"
    gadmin start -v
    gsql --reset
  else
    echo "Fail!"
    if [ ! -z "$test_name" ]; then
      sed -i "/${test_name} (running)/d" $summary_file
      run_t=$(echo "scale=1; ($(date +%s) - $start_t) / 60" | bc -l)
      if [[ "$exit_code" == "143" ]]; then
        echo "${test_name} ${run_t} min (uncompleted)" >> $summary_file
      else
        echo "${test_name} ${run_t} min (failed)" >> $summary_file
      fi
      all_run_t=$(echo "scale=1; ($(date +%s) - $all_start_t) / 60" | bc -l)
      echo "Total ${all_run_t} min" >> $summary_file
    fi
    collect_log
  fi
}
trap finally exit
trap 'exit 143' TERM INT

# configure timeout for test
timeout_t=500
~/.gium/gadmin --set Online.Request.Timeout $timeout_t
~/.gium/gadmin --set Perf.gpe.Request.Timeout $timeout_t > /dev/null
~/.gium/gadmin --set Perf.restpp.Request.Timeout $timeout_t > /dev/null
~/.gium/gadmin --set Restpp.timeout_seconds $timeout_t > /dev/null
~/.gium/gadmin --set Restpp-Loader.timeout_seconds $timeout_t > /dev/null
~/.gium/gadmin --set Kafka-Loader.timeout_seconds $timeout_t

gadmin config-apply
########################################################################################
