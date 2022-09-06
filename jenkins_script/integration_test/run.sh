#!/bin/bash
########################################################
cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
cd $cwd
# test validation
if [[ $# > 5 || $# == 0 ]]; then
  echo "Usage: ./run.sh /path/to/folder [-h] [-i integration_tests] [-skip_bc]"
  exit 1
fi
########################################################
LOG_FOLDER=$1
if [ -f $LOG_FOLDER ]
then
  echo -e "Error : $LOG_FOLDER is not a folder!"
  exit 1
fi
mkdir -p $LOG_FOLDER || true
LOG_FILE=$LOG_FOLDER/integration_test.log
shift 1

hourly=false
skip_bc=false
all_regress_type=' shell loader gquery docExampleTest '
# use 'all' to run all default regress in one specific test
regress_default='all'
# default to run all shell, loader, gquery, docExampleTest
integration_tests="shell: ${regress_default}; loader: ${regress_default}; gquery: ${regress_default}; docExampleTest: ${regress_default}"
while [[ $# -gt 0 ]]; do
  if [ "$1" = "-h" ]; then
    hourly=true
    shift 1
  elif [ "$1" = "-skip_bc" ]; then
    skip_bc=true
    shift 1
  elif [ $1 = "-i" ]; then
    if [[ "$2" != "all" ]]; then
      integration_tests=$2
    fi
    shift 2
  else
    echo "Usage: ./run.sh /path/to/folder [-h] [-i integration_tests]"
    exit 1
  fi
done

# record integration tests each regress time cost
summary_file=$LOG_FOLDER/integration_test_summary
rm -rf $summary_file
#########################################################
# parse integration_tests into arrays
declare -A it_map
# split the string by ';' to get several tests with different types
IFS=';' read -r -a arr <<< "$integration_tests"
for ele in "${arr[@]}"; do
  # cut ':' to get the type name and regress numbers
  regress_type=$(echo ${ele} | cut -d ':' -f1 | cut -d ' ' -f 1)
  if [[ -z "${regress_type}" ]]; then
    continue
  fi
  # if the type name does not in declared types, ignore it
  if [[ " $all_regress_type " =~ " $regress_type " ]]; then
    it_map[$regress_type]=" $(echo ${ele} | cut -d ':' -f2) "
    echo "$regress_type: ${it_map[$regress_type]}"
  fi
done

echo "LOG_FOLDER = $LOG_FOLDER"
echo "integration_tests = $integration_tests"

########################################################
# some common setup that is shared with gsql unit test
script_name='integration'
really_fail=false
source $cwd/../env_setup.sh
source $cwd/../unittest/components/gle_setup.sh

# if no_fail is no smaller than 2, it will not exit for failure
if [[ "$NO_FAIL" -ge "2" ]]; then
  set +e
fi
#########################################################
if [[ $skip_bc == false ]]; then
  catalog_manager="$SHELL_SCRIPT_FOLDER/catalog_manager.sh"
  # gsql back compatible testing
  echo -e "\n run gsql back compatible testing"
  echo -e "\n restore catalog from previous backup"
  bash $catalog_manager 'restore' &> $LOG_FOLDER/bigtest_log/catalog_manager.log
  res_code=$?
  if [[ "$NO_FAIL" -ge "2" && $res_code != 0 ]]; then
    echo 'gsql backward compatibility test failed'
    really_fail=true
  fi
fi
#########################################################
# run test
cd $PRODUCT/gtest
test_name=""
all_start_t=$(date +%s)
sed -i 's/TimeOutMinutes=[0-9]*/TimeOutMinutes=30/g' config
# clear old output and diff
rm -rf diff/*
rm -rf output/*

#########################################################
## shell regresses
all_regress=$(ls -d test_case/shell/regress*)
for file in ${all_regress}
do
	num=${file##*regress}
  # if $num in it_map['shell'] or it_map['shell'] has 'all', then run this regress
  if [[ " ${it_map['shell']} " =~ " $num " || " ${it_map['shell']} " =~ " ${regress_default} " ]]; then
    start_t=$(date +%s)
    test_name="shell regress${num}"
    echo "${test_name} (running)" >> $summary_file
    echo -e "\nrun shell regress $num"
    echo -e "\nrun shell $num at $(date +'%F %T.%6N')" &>> $LOG_FILE
	  ./gtest shell.sh $num &>> $LOG_FILE

    res_code=$?
    sed -i "/${test_name} (running)/d" $summary_file
    run_t=$(echo "scale=1; ($(date +%s) - $start_t) / 60" | bc -l)

    # if unit test failed with no_fail option, print info and record in summary_file
    if [[ "$NO_FAIL" -ge "2" && $res_code != 0 ]]; then
      echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      echo "            ${test_name} failed! at $(date +'%F %T.%6N')"
      echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      echo "${test_name} ${run_t} min (failed)" >> $summary_file
      really_fail=true
    else
      echo "${test_name} ${run_t} min" >> $summary_file
    fi
  fi
done
sed -i 's/TimeOutMinutes=[0-9]*/TimeOutMinutes=20/g' config
#########################################################
## end2end regresses
all_type_tests="gquery loader docExampleTest"
for type in $all_type_tests; do
  all_regress=$(ls -d test_case/end2end/${type}/regress*)
  for file in ${all_regress}; do
    num=${file##*regress}
    if [[ " ${it_map[${type}]} " =~ " $num " || " ${it_map[${type}]} " =~ " ${regress_default} " ]]; then
      start_t=$(date +%s)
      test_name="${type} regress${num}"
      echo "${test_name} (running)" >> $summary_file
      echo -e "\nrun ${type} regress $num"
      echo -e "\nsetup ${type} regress $num at $(date +'%F %T.%6N')" &>> $LOG_FILE
      ./resources/end2end/${type}/regress$num/setup.sh &>> $LOG_FILE
      echo -e "\nrun ${type} regress $num at $(date +'%F %T.%6N')" &>> $LOG_FILE
      ./gtest end2end.sh ${type} $num &>> $LOG_FILE

      res_code=$?
      sed -i "/${test_name} (running)/d" $summary_file
      run_t=$(echo "scale=1; ($(date +%s) - $start_t) / 60" | bc -l)

      # if unit test failed with no_fail option, print info and record in summary_file
      if [[ "$NO_FAIL" -ge "2" && $res_code != 0 ]]; then
        echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "            ${test_name} failed! at $(date +'%F %T.%6N')"
        echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "${test_name} ${run_t} min (failed)" >> $summary_file
        really_fail=true
      else
        echo "${test_name} ${run_t} min" >> $summary_file
      fi
    fi
  done
done

sed -i 's/TimeOutMinutes=[0-9]*/TimeOutMinutes=15/g' config
all_run_t=$(echo "scale=1; ($(date +%s) - $all_start_t) / 60" | bc -l)
echo "Total ${all_run_t} min" >> $summary_file
test_name=""

# check really_fail variable and touch a file "really_fail_flag" for checking and exiting later.
if [[ "$NO_FAIL" -ge "2" && $really_fail == true ]]; then
  touch $LOG_FOLDER/really_fail_flag
  echo -e "\n\nIntegration test failed, but script will not exit due to no_fail option enabled"
else
  echo -e "\n\nIntegration test passed!"
  # #########################################################
  # # backup catalog for gsql back compatible testing
  # if [[ $hourly == true ]]; then
  #   echo -e "\nbackup catalog for the next gsql backward compatibility testing"
  #   bash $catalog_manager 'backup' &> $LOG_FOLDER/bigtest_log/catalog_manager.log
  # fi
  # #########################################################
fi
