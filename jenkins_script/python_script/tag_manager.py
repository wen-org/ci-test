#!/usr/bin/python
import util
import sys, os.path

def set_tag(tag_name, version_filepath):
    """
    set tag names of all corresponding commits in all repos in version_file
    to tag_name
    Args:
        tag_name: a string, the tag name
        version_filepath: the output file path of jenkins
    """
    branch_signatures = util.get_branch_sha_dict(open(version_filepath).read())
    for repo, sha in branch_signatures.items():
        util.tag_branch_as_stable(repo, sha, tag_name)
    # end for
# end function set_tag

def delete_tag(tag_name, version_filepath):
    """
    set tag names of all corresponding commits in all repos in version_file
    to tag_name
    Args:
        tag_name: a string, the tag name
        version_filepath: the output file path of jenkins
    """
    branch_signatures = util.get_branch_sha_dict(open(version_filepath).read())
    for repo, sha in branch_signatures.items():
        util.delete_tag(repo, tag_name)
    # end for
# end function set_tag

def main(parameters):
    util.check(len(parameters) == 4, RuntimeError,
        "Invalid arguments: " + str(parameters[1:]))
    tag_name = parameters[1]
    version_file = parameters[2]
    method = parameters[3]
    if not os.path.exists(version_file):
        print 'version_file does not exists'
        sys.exit(0)
    if method == 'create':
        set_tag(tag_name, version_file)
    elif method == 'delete':
        delete_tag(tag_name, version_file)
    else:
        print 'Invalid method arguments'
# end function main

##############################################
# Arguments:
#   0: this script name
#   1: tag name
#   2: version_file path
##############################################
if __name__ == "__main__":
    try:
        main(sys.argv)
    except Exception, msg:
        # print error to stderr and not exit 1 for Jenkins to check stderr
        util.print_err(str(msg))
