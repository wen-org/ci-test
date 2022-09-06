#!/usr/bin/python
# read integration time_cost json file and group each regress

import sys, os.path, json, math, random

# back tracking to get path to start_pos
def back_track_path(possible_sums, edge_set, group_arr, start_pos):
    if float(start_pos) == 0:
        return True
    for start_pos_val in possible_sums[start_pos]:
        edge_id = start_pos_val.split()[1]
        next_pos = start_pos_val.split()[0]
        if edge_id not in edge_set:
            edge_set.add(edge_id)
            group_arr.append(round(float(start_pos) - float(next_pos), 1))
            if back_track_path(possible_sums, edge_set, group_arr, next_pos):
                return True
            edge_set.remove(edge_id)
            group_arr.pop(len(group_arr) - 1)
    return False


# Use dp to get most approximate group from dict2arr
def dp_approximate(time_cost_dict, dict2arr, target):
    # get all possible_sums
    possible_sums = {"0": set(["0 -1"])}
    for i in range(0, len(dict2arr)):
        kv_p = dict2arr[i].split()
        cost = time_cost_dict[kv_p[0]][kv_p[1]]
        extra_set = {}
        for p_key, p_val in possible_sums.iteritems():
            if float(p_key) >= target:
                continue
            new_key = str(float(p_key) + float(cost))
            extra_set[new_key] = possible_sums[new_key] if new_key in possible_sums else set()
            extra_set[new_key].add(p_key + " " + str(i))
        possible_sums.update(extra_set)

    # get p_key nearest to the target
    dis_target = sys.maxint
    nearest_p_key = "0"
    for p_key, p_val in possible_sums.iteritems():
        if float(p_key) != 0 and abs(float(p_key) - target) < dis_target:
            dis_target = abs(float(p_key) - target)
            nearest_p_key = p_key

    # back track to get combination(path) in possible_sums
    group_arr = []
    if nearest_p_key != "0":
        edge_set = set()
        back_track_path(possible_sums, edge_set, group_arr, nearest_p_key)

    # In cost combination, cost -> key in dict
    res_arr = []
    index = 0
    while index < len(dict2arr):
        kv_p = dict2arr[index].split()
        cost = float(time_cost_dict[kv_p[0]][kv_p[1]])
        if cost in group_arr:
            res_arr.append(dict2arr[index])
            dict2arr.pop(index)
            group_arr.remove(cost)
        else:
            index += 1
    return res_arr


# Use greedy to call dp_approximate to get all groups
def greedy_groups(time_cost_dict, dict2arr, num_group, target, unittests_group_totals):
    res = []
    for i in range(0, num_group - 1):
        if target > unittests_group_totals[i]:
            res.append(dp_approximate(time_cost_dict, dict2arr, target - unittests_group_totals[i]))
        else:
            res.append([])
    return res


def average_arr(arr):
    total = 0
    for elem in arr:
        total += float(elem)
    return round(total / float(len(arr)), 1)


def main(parameters):
    if len(parameters) < 6:
        print "Invalid arguments: " + str(parameters[1:])
        sys.exit(1)
    time_cost_file = parameters[1]
    num_group = int(parameters[2])
    unittests = parameters[3]
    integration_tests = parameters[4].strip()
    log_file = parameters[5]

    log_f = open(log_file, 'w')
    log_f.write('start to group integration test\n')

    # get unittests_groups
    unittests_groups = unittests.split('#')
    unittests_group_totals = []
    unittests_total = 0
    for ut_group in unittests_groups:
        ut_content = ut_group.split('@')[0].strip()
        ut_total = float(ut_group.split('@')[1].strip())
        unittests_total += ut_total
        unittests_group_totals.append(ut_total)


    time_cost_dict = {}
    with open(time_cost_file) as time_cost_data:
        time_cost_dict = json.load(time_cost_data)

    total = unittests_total
    threshold = 0
    dict2arr = []
    tmp_dict = {}
    if integration_tests != "none":
        for its in integration_tests.split(';'):
            if not its:
                continue
            it = its.split(':')
            name = it[0].strip()
            tmp_dict[name] = {}
            for regress_num in it[1].strip().split():
                regress_name = "regress" + str(regress_num)
                if name in time_cost_dict and regress_name in time_cost_dict[name]:
                    tmp_dict[name][regress_name] = str(average_arr(time_cost_dict[name][regress_name]))
                else:
                    tmp_dict[name][regress_name] = "1"
                total += float(tmp_dict[name][regress_name])
                dict2arr.append(name + " " + regress_name)
        threshold = total / float(num_group)

    time_cost_dict = tmp_dict

    log_f.write('The average threshold is ' + str(threshold) + '\n\n')
    res_dict = greedy_groups(time_cost_dict, dict2arr, num_group, threshold, unittests_group_totals)
    # Get the last group
    res_dict.append(dict2arr)

    res_str = ''
    for index, group in enumerate(res_dict):
        res_str += "# " if res_str else " "
        group_total = 0
        log_f.write('Group ' + str(index) + ' :\n')
        if len(group) == 0:
            res_str += "none "
        else:
            random.shuffle(group)
            tmp_dict = {}
            for kv_str in group:
                kv_p = kv_str.split()
                if kv_p[0] not in tmp_dict:
                    tmp_dict[kv_p[0]] = {}
                tmp_dict[kv_p[0]][kv_p[1]] = time_cost_dict[kv_p[0]][kv_p[1]]
            for tp, regress in tmp_dict.iteritems():
                res_str += tp + ":"
                for name, cost in regress.iteritems():
                    res_str += " " + name[7:]
                    group_total += float(cost)
                    log_f.write(tp + ' ' + name + ' ' + cost + '\n')
                res_str += "; "
        res_str += "@" + str(group_total)
        log_f.write('Total ' + str(group_total) + '\n\n\n')
    log_f.write(res_str)    
    log_f.close()
    return res_str
# end function main

##############################################
# Arguments:
#   0: this script name
#   1: time_cost json file
#   2: group number
#   3: unittests
#   4: integration tests
##############################################
if __name__ == "__main__":
    print main(sys.argv)
