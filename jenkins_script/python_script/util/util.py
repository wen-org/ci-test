#!/usr/bin/python
import sys, os.path, datetime, subprocess, re
import requests, json

def check(condition, error, msg):
    if not(condition):
        raise error, msg
    # end if
# end function check

class GithubAPIFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class GithubAPIFail

class MergeFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class MergeFail

class NotifyFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class NotifyFail

class validateFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class validateFail

class OpenIssueFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class OpenIssueFail

class AdvanceTagFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class AdvanceTagFail

class IssueExistanceFail(RuntimeError):
    def __init__(self, arg):
        self.args = [arg]
# end class IssueExistanceFail

def print_err(msg):
    sys.stderr.write(msg + '\n')

def send_http_request(url, headers, method, data=None, params={}):
    #requests.packages.urllib3.disable_warnings()
    if method == 'GET':
        response = requests.get(url, headers=headers, data=data, params=params)
    elif method == 'POST':
        response = requests.post(url, headers=headers, data=data, params=params)
    elif method == 'PUT':
        response = requests.put(url, headers=headers, data=data, params=params)
    elif method == 'DELETE':
        response = requests.delete(url, headers=headers, data=data, params=params)
    else:
        raise RuntimeError, 'Unkown http method'
    # end if-else
    return response
# end function send_http_request


def send_http_request_auth(url, headers, method, data = None, params = {}, user_name = '', password = ''):
    #requests.packages.urllib3.disable_warnings()
    if method == 'GET':
        response = requests.get(url, headers=headers, data=data, params=params, auth=(user_name, password))
    elif method == 'POST':
        response = requests.post(url, headers=headers, data=data, params=params, auth=(user_name, password))
    elif method == 'PUT':
        response = requests.put(url, headers=headers, data=data, params=params, auth=(user_name, password))
    elif method == 'DELETE':
        response = requests.delete(url, headers=headers, data=data, params=params, auth=(user_name, password))
    else:
        raise RuntimeError, 'Unkown http method'
    # end if-else
    return response
# end function send_http_request_auth

def run_bash(cmd):
    try:
        result = subprocess.check_output(["bash", "-c", cmd])
    except subprocess.CalledProcessError:
        raise RuntimeError, "Fail to run bash command '" + cmd + "'"
    # end try-catch
    # remove last '\n' char
    return result[:-1]
#end function run_bash

def parse_parameter(parameters, index):
    """
    Parse rep1#pull_number1 rep2#pull_number2 ... to a directory
    Args:
        parameters: parameters array
        index: index number of parameters
    Returns:
        A dictionary of repo and pull request key value pair
    TODO:
        This case should been taken care of:
        Can not have two same repos regardless of pull_number
    """
    if len(parameters) <= index:
        return {}
    # end if
    dict = {}
    for var in parameters[index].split(';'):
        if var == "":
            continue
        check(len(var.split('#')) == 2, RuntimeError,
                "Invalid argument: " + var)
        repo = var.split('#')[0].lower()
        pull_req = var.split('#')[1]
        if repo in dict:
            raise validateFail, "can not have mutliple " + repo
        dict[repo] = pull_req
    # end for
    return dict
# end function parse_parameter

def prepare_log(directory, log_name):
    """
    Create log file and rename it with timestamp
    Args:
        directory: directory of log file
        log_name: log file name
    Returns:
        log file path
    """
    directory = os.path.expanduser(directory)
    if not(os.path.isdir(directory)):
        os.makedirs(directory)
    # end if
    log_file = directory + "/" + log_name
    if os.path.isfile(log_file):
        time = str(datetime.datetime.now()).replace(' ', '.')
        os.rename(log_file, log_file + '.' + time)
    # end if
    return log_file
# end function prepare_log

def get_branch_sha_dict(text):
    """
    Get branch sha values from given log file by filtering related lines
    Args:
        text: log text
    Returns:
        a dict of sha values, e.g.: {"gle": "771e133b719eb037b7b990566f451939d77c4b22"}
    """
    lines = text.split("\n")
    lines = [line.split() for line in lines if len(line.split()) >= 3 and re.match("^[a-z0-9]{40}$", line.split()[2])]
    res = {}
    for t in lines:
        res[t[0]] = t[2]
    return res
# end function get_branch_sha_dict


def read_config_file():
    """
    Args:
        read config json file
    """
    config_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../config/config.json')
    configs = ''
    with open(config_file) as config_json:
        configs = json.load(config_json)
    return configs
