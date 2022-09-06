#!/bin/bash

cwd=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
cd ${cwd}
source ${cwd}/../util.sh
set -e

# test validation
if [[ $# < 2 ]]; then
  echo "Usage: ./get_integrations.sh integrations gle_branch"
  exit 1
fi
integrations=$1
branch_name=$2

if [[ "$integrations" == "none" ]]; then
  echo "all integrations tests: none"
  exit 0
fi

customized=false
if [[ "$integrations" != "all" && "$integrations" != "default" ]]; then
  customized=true
fi

#################################################################
## parse customized integrations

all_regress_type=' shell loader gquery docExampleTest '
# use 'all' to run all default regress in one specific test
regress_default='all'

# parse integrations into arrays
declare -A it_map
# split the string by ';' to get several tests with different types
IFS=';' read -r -a arr <<< "$integrations"
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

#########################################################
GIT_USER=$(jq -r .GIT_USER ${cwd}/../config/config.json)
GIT_TOKEN=$(jq -r .GIT_TOKEN ${cwd}/../config/config.json)
repo_name='gle'
repo_path="/tmp/${repo_name}"
rm -rf ${repo_path}
git clone -b $branch_name \
  https://$GIT_USER:$GIT_TOKEN@github.com/TigerGraph/${repo_name}.git ${repo_path} --depth=1
res_code=$?
echo "git clone exit code : $res_code"
cd ${repo_path} && ls
git pull
res_code=$?
echo "git pull exit code : $res_code"
cd regress

res_str=""
tmp_str="shell:"
all_regress=$(ls -d test_case/shell/regress*)
for file in ${all_regress}; do
  num=${file##*regress}
  if [[ "$customized" == "false" || " ${it_map['shell']} " =~ " $num " || \
      " ${it_map['shell']} " =~ " ${regress_default} " ]]; then
    tmp_str="${tmp_str} ${num}"
  fi
done
if [[ "$tmp_str" != "shell:" ]]; then
  res_str="${res_str}${tmp_str}; "
fi

all_type_tests="gquery loader docExampleTest"
for type in $all_type_tests; do
  tmp_str="${type}:"
  all_regress=$(ls -d test_case/end2end/${type}/regress*)
  for file in ${all_regress}; do
    num=${file##*regress}
    if [[ "$customized" == "false" || " ${it_map[${type}]} " =~ " $num " || \
        " ${it_map[${type}]} " =~ " ${regress_default} " ]]; then
      tmp_str="${tmp_str} ${num}"
    fi
  done
  if [[ "$tmp_str" != "${type}:" ]]; then
    res_str="${res_str}${tmp_str}; "
  fi
done
cd -
rm -rf ${repo_path}
echo "all integrations tests: ${res_str}"
