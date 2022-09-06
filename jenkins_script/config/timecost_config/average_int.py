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

total = 0
for regress, it in time_cost_dict.iteritems():
  for name, costs in it.iteritems():
    cost = average_arr(costs)
    print regress + " " + name + " : " + str(cost)
    total += cost
print "total: " + str(total)
