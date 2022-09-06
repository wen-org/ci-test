#!/usr/bin/python
import util
import sys, os.path, re
from tag_manager import set_tag

def get_default_branches(default, BIGTEST_BASE_BRANCH):
    branches = {
        'olgp': default,
        'topology': default,
        'gpe': default,
        'gse': default,
        'third_party': default,
        'utility': default,
        'realtime': default,
        'er': default,
        'tut': default,
        'glelib': default,
        'bigtest': BIGTEST_BASE_BRANCH,
        'pta': default,
        'glive': default,
        'gui': default,
        'gvis': default,
        'blue_features': default,
        'blue_commons': default,
        'product': default,
        'document': default,
        'gium': default,
        }
    return branches
# end function get_default_branches

def update_prject_config(branches, tag):
    cmd = "sed '"
    for repo, branch in branches.iteritems():
        cmd = cmd + "s/" + repo + "\(.*\)BRANCH\(.*\)latest/" + repo + "\\1" + branch + "\\2" + tag + "/;"
    # end for
    cmd = cmd + "' bigtest/proj_config.template > config/proj.config"
    util.run_bash(cmd)
# end function update_prject_config

def write_gium_sha_to_version_file(branches, version_file):
    """
    write gium sha to version file
    Args:
        repo_dict: a dictionary of repo name -> pull request number key value pair
        branches: a dictionary of repo name -> branch name key value pair
        version_file: version_file path
    """
    print 'write gium to version_file'
    repo = 'gium'
    branch = branches[repo]
    sha = util.get_branch_lastest_commit(repo, branch)
    date = util.get_commit_from_sha(repo, sha)['commit']['committer']['date']
    info = repo + '                 ' + \
            branch + '               ' + \
            sha + ' ' + date
    util.run_bash('echo "' + info + '" >> ' + version_file)
# end function write_gium_sha_to_version_file

def main(parameters):
    os.chdir(os.environ['PRODUCT'])

    util.check(len(parameters) >= 7, RuntimeError,
        "Invalid arguments: " + str(parameters[1:]))
    util.check(os.path.isfile('gworkspace.sh'), RuntimeError,
        "Invalid working directory, gworkspace.sh doesn't exist")
    log_dir = parameters[1]
    log_file = util.prepare_log(log_dir, 'gworkspace.log')

    branches = get_default_branches(parameters[2], parameters[3])
    commits = get_default_branches('latest', 'latest')
    p_dict = util.parse_parameter(parameters, 4)
    print 'Repository and pull requests: ' + str(p_dict)
    version_file = parameters[5]
    mark_tag_name = parameters[6]
    test_by_tag = ''
    if len(parameters) > 7:
        test_by_tag = parameters[7]

    for repo, num in p_dict.iteritems():
        branch = util.get_pull_request_branch_name(repo, num)
        branches[repo] = branch
    print 'Repository and branches: ' + str(branches)

    update_tag = 'latest'
    cmd = ''
    # if version_file already exists(tag is created) or test_tag is specified,
    #     just need to check out the tag
    if os.path.exists(version_file) or test_by_tag != '':
        update_tag = mark_tag_name
        cmd = '(git reset --hard && git fetch --all && git checkout ' + \
            mark_tag_name + ') &> ' + log_file
    else:
        cmd = '(git reset --hard && git fetch --all && git checkout ' + \
            branches['product'] + ' && git reset --hard origin/' + \
            branches['product']  + ') &> ' + log_file
    util.run_bash(cmd)

    update_prject_config(branches, update_tag)
    util.run_bash('./gworkspace.sh -r &> ' + log_file)

    if not os.path.exists(version_file):
        util.run_bash('./gworkspace.sh -c &> ' + version_file)
        # print gium commit to version file so that merge_job can get the gium sha
        write_gium_sha_to_version_file(branches, version_file)

        # if the pipeline does not specifies the tag, mark it with a temp tag
        if test_by_tag == '':
            set_tag(mark_tag_name, version_file)
# end function main

##############################################
# Arguments:
#   0: this script name
#   1: master machine IP
#   2: master machine login info
#   3: log directory, it should be /log_dir/${BUILD_NUMBER}/
#   4: default branch name, for repos other than testing repos
#   5: bigtest base branch
#   6: jenkins parametes, include repo name and pull request number (optional)
##############################################
if __name__ == "__main__":
    try:
        main(sys.argv)
    except Exception, msg:
        # print error to stderr and not exit 1 for Jenkins to check stderr
        util.print_err(str(msg))
