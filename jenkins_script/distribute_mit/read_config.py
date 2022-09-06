#!/usr/bin/env python

import os
import sys
import json

class colors:
  RED   = "\033[1;31m"
  BLUE  = "\033[1;34m"
  CYAN  = "\033[1;36m"
  GREEN = "\033[0;32m"
  RESET = "\033[0;0m"
  BOLD    = "\033[;1m"
  REVERSE = "\033[;7m"

def main(json_file, output_file):
  try:
    json_obj = json.load(open(json_file))
    # save the ouptut after converting into a list
    output = {}
    # initialize output
    output["nodes_ip"] = []
    output["nodes_login"] = []
    for key, value in json_obj.iteritems():
      print "Parsing config item: " + key
      if key == "nodes.ip":
        for node, ip in value.iteritems():
          # value is a dict
          if node in output["nodes_ip"]:
            print colors.RED + "[ERROR]: duplicate node item exists (" + node + ")" \
                  + " in nodes.ip" + colors.RESET
            sys.exit(1)
          output["nodes_ip"].append(node)
          if node in output:
            output[node] = ip + " " + output[node]
          else:
            output[node] = ip
      elif key == "nodes.login":
        for node, login in value.iteritems():
          if node in output["nodes_login"]:
            print colors.RED + "[ERROR]: duplicate node item exists (" + node + ")" \
                  + " in nodes.login" + colors.RESET
            sys.exit(1)
          output["nodes_login"].append(node)
          if node in output:
            output[node] = output[node] + " " + login
          else:
            output[node] = login
      elif key == "gpe.server" or key == "gse.server":
        output[key + ".replicas"] = str(value["replicas"])
        output[key + ".nodes"] = ','.join(value["nodes"])
      elif key == "restpp.server" or key == "zk.server" or key == "kafka.server":
        output[key + ".nodes"] = ','.join(value["nodes"])
      else:
        output[key] = str(value)

    if sorted(output["nodes_login"]) != sorted(output["nodes_ip"]):
      print colors.RED + "[ERROR]: nodes from nodes.ip [" + ','.join(sorted(output["nodes_ip"])) \
            + "] are not match with nodes from nodes.login [" + ','.join(sorted(output["nodes_login"])) \
            + "]" + colors.RESET
      sys.exit(1)
    else:
      output["all_nodes"] = ','.join(sorted(output["nodes_login"]))
      for server in ['gpe.server','gse.server','restpp.server','zk.server','kafka.server']:
        if not set(json_obj[server]["nodes"]).issubset(output["nodes_ip"]):
          print colors.RED + "[ERROR]: nodes from " + server + " [" + output[server + ".nodes"] \
                + "] is not subset of nodes from nodes.ip [" + output["all_nodes"] + "]" + colors.RESET
          sys.exit(1)
      #if len(output["nodes_ip"]) < 2:
      #   print colors.RED + "[ERROR]: the number of nodes of the cluster must be 2 or more" + colors.RESET
      #   sys.exit(1)
      output.pop("nodes_ip", None)
      output.pop("nodes_login", None)

    with open(output_file, 'w') as fout:
      for key, value in output.iteritems():
        # must replace '.' with '_', otherwise file cannot be sourced in bash script
        fout.write(key.replace('.', '_') + "=\"" + value + "\"\n")
  except Exception as e:
    print colors.RED + "[ERROR]: error occurs when parsing JSON config file cluster_config.json" + colors.RESET
    print "Error Message: %s" %e
    sys.exit(1)

##############################################
# Arguments:
#   0: this script name
#   1: string, input json file name
##############################################
if __name__ == "__main__":
  if len(sys.argv) < 3:
    print 'No parameter provided, usage: python ' + sys.argv[0] + ' input_file output_file'
    sys.exit(1)

  if not os.path.isfile(sys.argv[1]):
    print 'input file NOT exist: ' + sys.argv[1]
    sys.exit(2)

  main(sys.argv[1], sys.argv[2])
