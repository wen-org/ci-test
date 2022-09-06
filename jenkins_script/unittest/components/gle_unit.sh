#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})
source ../env.sh

save_workspace

source gle_setup.sh
gadmin stop vis -vy

cd $PRODUCT/gtest

# clear old output and diff
rm -rf diff/*
rm -rf output/*

# change the number of threads to 1
sed -i 's/numThreads=[0-9]*/numThreads=1/g' config

# run test
all_regress=$(ls -d test_case/gsql/ddl/regress*)
for file in ${all_regress}
do
	num=${file##*regress}
  echo -e "\nrun ddl regress $num at $(date +'%F %T.%6N')"
	./gtest gsql.sh ddl $num
done

# change the number of threads back to 16
sed -i 's/numThreads=[0-9]*/numThreads=16/g' config
