#!/usr/bin/python
import util
import sys, os.path, time

def mergeable_check(repo_dict):
    """
    check each pull request in repo_dict if it is mergeable.
    If any pull request is not mergeable, abort the program.
    Args:
        repo_dict: a dictionary of repo -> pull requst
    """
    for repo, num in repo_dict.iteritems():
        pr = util.get_pull_request_info(repo, num)
        # if mergeable is null, it means github is not ready, we retry
        if pr['mergeable'] is None:
            time.sleep(3)
            mergeable_check(repo_dict)
        elif not pr['mergeable']:
            print pr
            raise util.MergeFail, repo + '#' + str(num) + ' is not mergeable! Please merge your feature branch with master.'
    # end for
# end function mergeable_check

def merge_pull_request(repo_dict, url, version_file):
    """
    get commit number

    GLE repo is special, since GLE is protected, and only GLELIB is open
    to other teams, the version file only has glelib sha, but we need to
    get the sha for GLE repo
    GLELIB commit message contains corresponding GLE commit number
    Args:
        repo_dict: a dict of repo -> pull request
        url: jenkins url
        version_file: a file with information of repo, branch, commit
    """
    repo_commits = util.get_branch_sha_dict(open(version_file).read())
    for repo, num in repo_dict.iteritems():
        branch_name = util.get_pull_request_branch_name(repo, num)
        if repo == 'gle':
            # messages in glelib has fixed format:
            # update glelib for 24e9b1105a2aea8dbc612d24a257a4b82c9afb24
            msg = util.get_commit_from_sha('glelib', repo_commits['glelib'])['commit']['message']
            # the fourth string is the sha for gle repo
            sha = msg.split(' ')[3]
        else:
            sha = repo_commits[repo]
        print 'merging pull request ' + repo + '#' + num + ' with sha: ' + sha
        util.merge_pull_request(repo, num, url, sha)
        util.delete_branch(repo, branch_name)
        if repo == 'gle':
            util.delete_branch('glelib', branch_name)
    # end for
# end

def main(parameters):
    util.check(len(parameters) == 4, RuntimeError,
        "Invalid arguments: " + str(parameters[1:]))

    dict = util.parse_parameter(parameters, 1)
    # make sure all pull reuqests are mergeable
    mergeable_check(dict)
    # then merge one by one
    merge_pull_request(dict, parameters[2], parameters[3])
# end function main


##############################################
# Arguments:
#   0: this script name
#   1: jenkins parametes, include repo name and pull request number
#   2: jenkins url, this is to record in commit msg
#   3: version file, which contains sha, the commit number
#      we use to test, to ensure no commit after test
##############################################
if __name__ == "__main__":
    try:
        main(sys.argv)
    except Exception, msg:
        # print error to stderr and not exit 1 for Jenkins to check stderr
        util.print_err(str(msg))
