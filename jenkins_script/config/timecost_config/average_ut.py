import sys, os.path, json, math, random

def average_arr(arr):
    total = 0
    for elem in arr:
        total += float(elem)
    return round(total / float(len(arr)), 1)

time_cost_file = sys.argv[1]
time_cost_dict = {}
with open(time_cost_file) as time_cost_data:
  time_cost_dict = json.load(time_cost_data)

new_dict = {}

for ut, costs in time_cost_dict.iteritems():
  total = 0
  new_dict[ut] = average_arr(costs)
  print "ut: " + ut + " ; cost: " + str(new_dict[ut]) + "\n"

if len(sys.argv) < 3:
  sys.exit(0)

print '--------------------------------------------------'
depend_json_file = sys.argv[2]
depend_dict = {}
with open(depend_json_file) as depend_json_data:
  depend_dict = json.load(depend_json_data)
for repo, units in depend_dict.iteritems():
  total = 0
  for unit in units.split():
    total += new_dict[unit]
  print "repo: " + repo + " ; avg: " + str(total) + "\n"
