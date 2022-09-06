#!/usr/bin/python
# get all unittests from unittests_dependency.json

import sys, os.path, json, math, random

def main(parameters):
    if len(parameters) < 4:
        print "Invalid arguments: " + str(parameters[1:])
        sys.exit(1)
    depend_json_file = parameters[1]
    param = parameters[2]
    unittests = parameters[3]
    job_id = parameters[4]
    all_unittests = parameters[5]
    if unittests == "all" or (unittests == "default" and job_id == 'HOURLY'):
        return all_unittests
    if unittests != "default":
        return unittests
    depend_dict = {}
    with open(depend_json_file) as depend_json_data:
        depend_dict = json.load(depend_json_data)
    res_unit = ''
    for pr in param.split(';'):
        if pr == "":
            continue
        if len(pr.split('#')) != 2:
            print "Invalid PARAM"
            sys.exit(1)
        repo = pr.split('#')[0].lower().strip()
        if repo not in depend_dict:
            continue
        for unit in depend_dict[repo].split():
            if unit and unit not in res_unit:
                res_unit = (res_unit + " " if res_unit else "") + unit
    return res_unit
# end function main

##############################################
# Arguments:
#   0: this script name
#   1: unittests_dependency.json
#   2: pull request PARAM
#   3: unittests (default or customized)
##############################################
if __name__ == "__main__":
    print main(sys.argv)
