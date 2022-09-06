#!/bin/bash
############################################################################################
cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
cd $cwd
############################################################################################
# helper function to run tests print passing messages
function rununit()
{
  rm -rf $LOG_FOLDER/$1_ut.log
  echo -e "================================================================="
  echo "               $1  unittests begin at $(date +'%F %T.%6N')!"
  echo -e "================================================================="
  if [ "$1" = "ium" ]; then
    bash ${cwd}/components/$1_unit.sh $ium_branch &> $LOG_FOLDER/$1_ut.log
  else
    bash ${cwd}/components/$1_unit.sh $2 $3 &> $LOG_FOLDER/$1_ut.log
  fi

  res_code=$?
  sed -i "/${test_name} (running)/d" $summary_file
  run_t=$(echo "scale=1; ($(date +%s) - $start_t) / 60" | bc -l)
  # if unit test failed with no_fail option, print info and record in summary_file
  if [[ "$NO_FAIL" -ge "2" && $res_code != 0 ]]; then
    echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    echo "               $1  unittests failed! at $(date +'%F %T.%6N')"
    echo -e "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    echo "${test_name} ${run_t} min (failed)" >> $summary_file
    really_fail=true
  else
    echo -e "================================================================="
    echo "               $1  unittests passed! at $(date +'%F %T.%6N')"
    echo -e "================================================================="
    echo "${test_name} ${run_t} min" >> $summary_file
  fi
}

function list_include_item() {
  local list="$1"
  local item="$2"
  if [[ "$list" == "all" || $list =~ (^|[[:space:]])"$item"($|[[:space:]]) ]] ; then
    # yes, list includes item
    result=0
  else
    result=1
  fi
  return $result
}

############################################################################################
# test validation
if [[ $# > 9 || $# == 0 ]]; then
  echo "Usage: ./run.sh /path/to/folder [-u unittests] [-b ium_branch]"
  exit 1
fi
############################################################################################
# get log folder
LOG_FOLDER=$1
if [ -f $LOG_FOLDER ]
then
  echo -e "Error : $LOG_FOLDER is not a folder!"
  exit 1
fi
mkdir -p $LOG_FOLDER || true
shift 1

ium_branch='master'
unittests_all=$(jq -r .all_unittests ${cwd}/../config/config.json)
unittests=$unittests_all
sanitizer=''
run_debug=''

# record integration tests each regress time cost
summary_file=$LOG_FOLDER/unit_test_summary
rm -rf $summary_file

while [[ $# -gt 0 ]]; do
  if [ $1 = "-u" ]; then
    if [[ "$2" != "all" ]]; then
      unittests=$2
    fi
    shift 2
  elif [ $1 = "-b" ]; then
    ium_branch=$2
    shift 2
  elif [ $1 = "-sanitizer" ]; then
    sanitizer="$1 $2"
    shift 2
  elif [ $1 = "-db" ]; then
    if [[ "$2" != "none" ]]; then
      run_debug=$2
    fi
    shift 2
  else
    echo "Usage: ./run.sh /path/to/folder [-u unittests] [-b ium_branch] [-db unit_test_to_debug] [-sanitizer type]"
    exit 1
  fi
done

echo "LOG_FOLDER = $LOG_FOLDER"
echo "unittests_all = $unittests_all"
echo "unittests = $unittests"

#########################################################
# some common setup
script_name='unittest'
really_fail=false
source $cwd/../env_setup.sh

# if no_fail is no smaller than 2, it will not exit for failure
if [[ "$NO_FAIL" -ge "2" ]]; then
  set +e
fi
############################################################################################
# Run unittest! Run!!!!!!!
test_name=""
all_start_t=$(date +%s)
for unit in $unittests; do
  if [[ " $unittests_all " =~ " $unit " ]]; then
    start_t=$(date +%s)
    test_name=$unit
    debug_flag=""
    if `list_include_item "$run_debug" "$unit"` ; then
      debug_flag="-db"
    fi
    echo "${test_name} (running)" >> $summary_file
    rununit $unit $sanitizer $debug_flag
  fi
done
all_run_t=$(echo "scale=1; ($(date +%s) - $all_start_t) / 60" | bc -l)
echo "Total ${all_run_t} min" >> $summary_file

# check really_fail variable and touch a file "really_fail_flag" for checking and exiting later.
if [[ "$NO_FAIL" -ge "2" && $really_fail == true ]]; then
  touch $LOG_FOLDER/really_fail_flag
  echo -e "\n\nUnit tests failed, but script will not exit due to no_fail option enabled"
else
  echo -e "\n\nAll unittests passed!"
fi
############################################################################################
