#!/bin/bash
# This script is a post-testing log collector.
# Arguments: log_dir
# We will collect following items:
#    1. ~/tigergraph/logs
#    2. ~/tigergraph/zk/zookeeper.out*
#    3. ~/tigergraph/zk/data_dir
#    4. ~/tigergraph/zk/conf
#    5. ~/tigergraph/kafka/kafka.out*
#    6. ~/tigergraph/dev/gdk/gsql/output/
#    7. GSQL_LOG
#    8. gadmin status -v > $log_dir/service_status
#    9. IUM version and ~/.gium
#    10. gadmin fab log (~/.gsql/fab_dir/cmd_logs)
#    11. ~/.gsql/
#    12. ~/tigergraph/dev/gdk/gsdk/allVERSIONS.txt
#    13. gtest/output
#    14. gtest/base_line
#    15. gtest/diff
#    16. tsar info
#    17. /var/log/message or syslog, df, dmesg
#    18. Add ut logs
##############################################
cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
source $cwd/../util.sh
set -x

if [ -z $NO_COLLECTION ]; then
  exit 0
fi

# validate
if [ $# -ne 1 ] || [ ! -d $1 ];then
  echo "Usage: $0 LOG_DIR"
  echo "LOG_DIR must be an existing directory"
  exit 1
fi

log_dir=$1
log_dir=$(cd $log_dir && pwd)

function copy_gtest () {
  local source_log_folder=$1
  local target_log_folder=$2
  mkdir -p $target_log_folder
  cp -RLp ${source_log_folder}/output    $target_log_folder 2>/dev/null
  cp -RLp ${source_log_folder}/base_line $target_log_folder 2>/dev/null
  cp -RLp ${source_log_folder}/diff      $target_log_folder 2>/dev/null
  cp -Rp ${source_log_folder}/.working_dir $target_log_folder/working_dir 2>/dev/null
}


# copy ~/tigergraph/logs
cp -RLp ${PROJECT_ROOT}/logs ${log_dir}/

# copy zookeeper info
mkdir ${log_dir}/zk
cp -p ${PROJECT_ROOT}/zk/zookeeper.out* ${log_dir}/zk/
cp -RLp ${PROJECT_ROOT}/zk/data_dir   ${log_dir}/zk/
cp -RLp ${PROJECT_ROOT}/zk/conf       ${log_dir}/zk/

# copy kafka log
mkdir ${log_dir}/kafka
cp -p ${PROJECT_ROOT}/kafka/kafka.out* ${log_dir}/kafka/

# copy GSQL log
mkdir ${log_dir}/gsql
cp -p ${GSQL_PATH}/logs/GSQL_LOG* ${log_dir}/gsql/ 2>/dev/null
cp -Rp ${GSQL_PATH}/output      ${log_dir}/gsql/ 2>/dev/null
cp -Rp ${GSQL_PATH}/.tmp        ${log_dir}/gsql/tmp 2>/dev/null

# keep service status
~/.gium/gadmin status -v &> ${log_dir}/service_status

# TODO can't get IUM version right now
# copy gium directory
cp -Rp ~/.gium ${log_dir}/gium
# copy ~/.gsql
cp -Rp ~/.gsql ${log_dir}/gsql_cfg
#####################################################################

ut_log=${log_dir}/unit_test_logs
mkdir ${ut_log}

# copy gtest output
copy_gtest ${PRODUCT}/gtest ${log_dir}/gtest

# black_box ut log
copy_gtest ${BIGTEST_FOLDER}/tests/gtest ${ut_log}/black_box

# blue_feature ut log
copy_gtest ${PRODUCT}/src/blue/features/gtest ${ut_log}/blue_feature

# rest ut
cp -RLp ${PRODUCT}/src/realtime/integrationtest/*.log ${ut_log}/realtime || true
cp -Rlp /tmp/${USER}_correctness ${ut_log}/realtime || true

# ium ut log
copy_gtest ${PRODUCT}/src/gium ${ut_log}/black_box
cp -rf /tmp/ium_test ${ut_log}/ || true
#####################################################################
# collect system info
mkdir ${log_dir}/sys
# tsar info
tsar --me -i 1 -n 1 &> ${log_dir}/sys/tsar_me.out
tsar --io -i 1 -n 1 &> ${log_dir}/sys/tsar_io.out
# system message/log
dmesg -T &> ${log_dir}/sys/dmesg.out
df -h &> ${log_dir}/sys/disk_info
# this requires sudo permission
sudo cp -p /var/log/messages ${log_dir}/sys 2>/dev/null && sudo chown $(whoami):$(whoami) ${log_dir}/sys/messages
sudo cp -p /var/log/syslog   ${log_dir}/sys 2>/dev/null && sudo chown $(whoami):$(whoami) ${log_dir}/sys/syslog
#####################################################################
# archive and compress logs
# since zk's data_dir contains sparse file,
# we need tar to keep the sparse file information
tar -czf ${log_dir}.tar.gz --sparse --directory=${log_dir}/.. $(basename ${log_dir})
echo -e "\033[31mlog collection finish\033[0m"
echo -e "\033[31mYou can download log.tar.gz by \
  'curl ftp://$(hostname -I | cut -d ' ' -f 1)/$(basename ${log_dir}.tar.gz) \
  -o $(basename ${log_dir}.tar.gz)'\033[0m"

# save detailed data (kafka data and binaries)
mkdir ${log_dir}/data
cp -Rp ${PROJECT_ROOT}/kafka/log_dir ${log_dir}/data/kafka_log_dir
cp -Rp ${PROJECT_ROOT}/bin ${log_dir}/data/
tar -cf ${log_dir}.data.tar --sparse --directory=${log_dir} data

echo -e "\033[31mbinary collection finish\033[0m"
echo -e "\033[31mYou can download data.tar.gz by \
  'curl ftp://$(hostname -I | cut -d ' ' -f 1)/$(basename ${log_dir}.data.tar) \
  -o $(basename ${log_dir}.data.tar)'\033[0m"
