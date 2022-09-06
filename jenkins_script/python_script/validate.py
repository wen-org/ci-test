#!/usr/bin/python
import util
import sys, os.path

def validate_path_keyword(repo, num, warning=''):
    pull_request_msg = "pull reuqest " + repo + "#" + num
    diff = util.get_pull_request_diff(repo, num)

    config = util.read_config_file()
    blacklist = config["diff_blacklist"]
    # Due to atlassian migration issue, the site name is still
    # graphsql. We shouldn't block the use of links in atlassian
    whitelist = config["diff_whitelist"]

    diff = diff.lower()
    # remove the word in whitelist so that it does not need to be checked
    for keyword in whitelist:
        diff = diff.replace(keyword, '')

    for line in diff.split('\n'):
        if line.startswith('+'):
            for keyword in blacklist:
                util.check(not keyword in line, util.validateFail,
                        warning + pull_request_msg +
                        " new code contains " + keyword + " keyword")
            #fi
        # end for
    # end for
# end function validate_path_keyword

def pre_validate(repo, num, force, base_branch):
    """
    pre-test validate check, which is done when merge request received
    caller: merge_request_pipeline, 'validate' stage
    1. repo name exists
    2. pull request open
    3. pull request approved by person other than qa
    4. no commit after approved (not checked now)
    5. base branch is correct

    Args:
        repo: repo name
        num: pull request number
        base_branch: expected base branch to be merged into
    """
    pr = util.get_pull_request_info(repo, num)
    pull_request_msg = "pull reuqest " + repo + "#" + num
    # check repo name exists and pull request open
    util.check(pr['state'] == 'open',
        util.validateFail, pull_request_msg + " is not open.")

    # base branch must be correct
    if base_branch != None and repo != 'bigtest':
        util.check(pr['base']['ref'] == base_branch,
                util.validateFail, pull_request_msg + " base branch must be " + base_branch)

    # validate the pull request contains the base_branch's lastest commit
    util.check(util.check_feature_branch_merged_base(repo, num),
        util.validateFail, pull_request_msg + " feature branch was not merged with the base branch.")

    warning_str = ''
    if force == 'true':
        warning_str = 'WARNING: '

    # last commit is approved by person other than qa
    util.check(util.check_pull_request_approved(repo, num),
            util.validateFail, warning_str + pull_request_msg + " is not approved after last commit.")

    # validate the pull reuqest, new code should not contains 'graphsql'
    validate_path_keyword(repo, num, warning_str)
# end function pre_validate

def wip_validate(repo, num):
    """
    wip-test validate check, which is done when merge request received
    caller: merge_request_pipeline, 'validate' stage
    1. repo name exists
    2. pull request open

    Args:
        repo: repo name
        num: pull request number
    """
    pull_request_msg = "pull reuqest " + repo + "#" + num
    # check repo name exists and pull request open
    util.check(util.get_pull_request_info(repo, num)['state'] == 'open',
        util.validateFail, "pull request " + repo + "#" + num + " is not open.")

    # validate the pull request contains the base_branch's lastest commit
    util.check(util.check_feature_branch_merged_base(repo, num),
        util.validateFail, "WARNING: " + pull_request_msg +
        " feature branch was not merged with the base branch. However this will not block your WIP.")
    # validate the pull reuqest, new code should not contains 'graphsql'
    validate_path_keyword(repo, num, "WARNING: ")
#end function wip_validate

# validate check, which is done when merge request start to test
# caller: gworkspace.py
# 1. repo name exists
# 2. pull request open
# 3. pull request approved by person other than qa
# 4. no commit after approved
# 5. also tag a 'pending' status to the head commit

# post-test validate check, which is done after test pass before merge
# caller: merge_pull_request_job
# 1. pull request approved by qa
# 2. no commit after last 'pending' status, and change status to 'success'


def validate(parameters):
    """
    Args:
    0: this script name
    1: jenkins parameters
    2: validate state: PRE IN POST WIP
    3: base_branch (optional for compatibility)
    """
    util.check(len(parameters) >= 4, RuntimeError,
        "Invalid arguments: " + str(parameters[1:]))
    dict = util.parse_parameter(parameters, 1)
    print 'Repository and pull requests: ' + str(dict)

    state = parameters[2]
    force = parameters[3]
    base_branch = None
    if len(parameters) >= 5:
        base_branch = parameters[4]
    # end if

    for repo, num in dict.iteritems():
        if state == 'PRE':
            pre_validate(repo, num, force, base_branch)
        elif state == 'IN':
            return
        elif state == 'POST':
            return
        elif state == 'WIP':
            wip_validate(repo, num)
        else:
            raise RuntimeError, "Invalid argument: " + state
        # end if
    # end for
# end function validate

##############################################
# Arguments:
#   0: this script name
#   1: jenkins parametes, include repo name and pull request number
#   2: validate state: PRE IN POST WIP
#   3: base branch name: e.g. master
##############################################
if __name__ == "__main__":
    try:
        validate(sys.argv)
    except Exception, msg:
        # print error to stderr and not exit 1 for Jenkins to check stderr
        util.print_err(str(msg))
