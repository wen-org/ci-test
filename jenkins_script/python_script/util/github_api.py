#!/usr/bin/python
import util
from util import send_http_request, read_config_file
import requests, json, time, re, os.path

def send_github_api_request(url_tail, method='GET', data = None, silent = False,
        params = {}, retry=30, retry_interval=60, plain = False):
    """
    Args:
        url_tail: a string, the part of url after http://api.github.com/repos/TigerGraph/
        method: a string, specifying the request type
        data: a dict, specify the data needed for POST
        silent: boolean value, print request result if it's set to False
        params: a dict, the data needed for GET
        retry: an int, the maximum number of retry
        retry_interval: an int, the interval between each retry
    Return:
        a dict, the request result from github
    """
    github_token = read_config_file()['GIT_TOKEN']
    headers = {
        'Accept' : 'application/vnd.github.black-cat-preview+json',
        'Authorization': 'token ' + github_token #qa token
        }
    url = 'https://api.github.com/repos/TigerGraph/' + url_tail
    while retry >= 0:
        try:
            response = send_http_request(url, headers, method, data, params)
            break
        except requests.exceptions.ConnectionError:
            print ("Unable to connect to github, retrying in {} seconds".format(retry_interval))
            time.sleep(retry_interval)
            retry -= 1
            if retry < 0:
                print ("Failed to connect to github, request aborted.")
                raise requests.exceptions.ConnectionError
            # end if
        # end try-catch
    # end while

    # HTTP request returned an unsuccessful status code
    if response.status_code >= 400:
        if silent == False:
            print response.json()
        if response.json()['message'] == 'Not Found':
            msg = "Http returns status code " + \
                  str(response.status_code) + \
                   ". Please check repository name and pull request number."
            raise util.GithubAPIFail, msg
    return response if plain else response.json()
# end function send_github_api_request


class Enum(set):
    def __getattr__(self, name):
        if name in self:
            return name
        raise AttributeError
# end class Enum
STATE = Enum(['APPROVE', 'REQUEST_CHANGES', 'COMMENT'])

########### pull reqest api ###########
def get_pull_request_info(repo, num):
    url_tail = repo + '/pulls/' + num
    return send_github_api_request(url_tail)
# end function get_pull_request_info

def get_pull_request_branch_name(repo, num):
    return get_pull_request_info(repo, num)['head']['ref']
# end function get_pull_request_branch_name

def get_pull_request_base_branch(repo, num):
    return get_pull_request_info(repo, num)['base']['ref']
# end get_pull_request_base_branch

def get_pull_request_commits(repo, num):
    """
    get all commits of a pull request into an array
    Args:
        repo: repo name
        num: pull request number
    Returns:
        An array of all commits
    """
    url_tail = repo + '/pulls/' + num + '/commits'
    commits = send_github_api_request(url_tail)
    commit_shas = []
    for commit in commits:
        commit_shas.append(commit['sha'])
    # end for
    return commit_shas
# end function get_pull_request_commits

def get_pull_request_reviews(repo, num, page_num):
    """
    get the latest commit of base branch which is in compared branch.
    Args:
        repo: the repo name of pull request
        num: pull request number
        page_num: page number
    """
    url_tail = repo + '/pulls/' + num + '/reviews?page=' + str(page_num)
    return send_github_api_request(url_tail, plain = True)
# end function get_pull_request_reviews

def check_pull_request_approved (repo, num):
    """
    check if a pull request is approved by user other than qa
    Args:
        repo: repo name
        num: pull request number
    Returns:
        boolean value,
        return true if one reviewer approved except 'qa'
    TODO:
        check if the reviewer approved after last commit of pull request
    """
    reviews_res = get_pull_request_reviews(repo, num, 1)
    total_num = 1
    qa_account = read_config_file()['GIT_USER'].lower()
    if reviews_res.links:
        # get last page url
        last_url = reviews_res.links['last']['url']
        # get the last page number from last page url
        total_num = int(re.search(r"page=(\d+).*$", last_url).group(1))
    # end if
    last_commit = get_pull_request_info(repo, num)['head']['sha']
    for i in range(1, total_num + 1):
        # get reviews from page i
        reviews = get_pull_request_reviews(repo, num, i).json()
        for review in reviews:
            user = review['user']['login']
            commit = review['commit_id']
            state = review['state']
            # 1. approved after last commit (not check now)
            # 2. user is not qa
            if state == 'APPROVED' and user != qa_account:
                return True
            # end if
        # end for
    # end for
    return False
# end function check_pull_request_approved

def push_comment_to_pull_request(repo, num, msg, state, silent = False):
    url_tail = repo + '/pulls/' + num + '/reviews'
    data = { "body": msg, "event":  state}
    pull_request = send_github_api_request(url_tail, 'POST', json.dumps(data), silent = silent)
    return pull_request
# end function push_comment_to_pull_request

def merge_pull_request(repo, num, url, sha):
    """
    Merge pull request.
    Args:
        repo: repo name
        num: pull request number
        url: build url
        sha: The commit number that pull request head must match to allow merge.
    """
    url_tail = repo + '/pulls/' + num + '/merge'
    commit_msg = 'Merged by QA@TigerGraph: ' + url
    data = {
        'sha': sha,
        'commit_message': commit_msg,
        'merge_method': 'squash'
        }
    response = send_github_api_request(url_tail, 'PUT', json.dumps(data))
    if response.get('merged', False) != True:
        raise util.GithubAPIFail, response.get('message')
    else:
        print response.get('message')
    # end if-else
# end function get_pull_request_info

def delete_branch(repo, branch_name):
    url_tail = repo + '/git/refs/heads/' + branch_name
    send_github_api_request(url_tail, 'DELETE', plain = True)

def delete_tag(repo, tag):
    url_tail = repo + '/git/refs/tags/' + tag
    send_github_api_request(url_tail, 'DELETE', plain = True)

def get_pull_request_merge_base_commit(repo, num):
    '''
    get the latest commit of base branch which is in compared branch.
    Args:
        repo: the repo name of pull request
        num: pull request number
    '''
    url_tail = repo + '/compare/' + get_pull_request_base_branch(repo, num) + \
        '...' + get_pull_request_branch_name(repo, num)
    return send_github_api_request(url_tail)['merge_base_commit']['sha']
# end get_pull_request_base_commit

def check_feature_branch_merged_base(repo, num):
    """
    check if the latest commit of base branch which is in compared branch is
    equal to the latest commit of base branch.
    Args:
        repo: the repo name of pull request
        num: pull request number
    Returns:
        boolean value
    """
    base_lastest_commit = get_branch_lastest_commit(repo, get_pull_request_base_branch(repo, num))
    pull_request_merge_base_commit = get_pull_request_merge_base_commit(repo, num)
    return base_lastest_commit == pull_request_merge_base_commit
# end function check_feature_branch_merged_base

def get_pull_request_diff(repo, num):
    url_tail = repo + '/pulls/' + num + '/files'
    response = send_github_api_request(url_tail)
    diff = ''
    for filee in response:
        if 'patch' in filee:
            diff += filee['patch']
    # end for
    return diff
# end function get_pull_request_info

########### commits api ###########
def get_commit_from_sha(repo, sha):
    url_tail = repo + '/commits/' + sha
    return send_github_api_request(url_tail)
# end function get_commit_from_sha

def get_commits(repo, sha, size):
    """
    Get recent commits
    Args:
        repo: the repo name
        sha: the last commit sha
        size: how many commits to retrieve
    """

    url_tail = repo + '/commits'
    params = {
        'per_page' : size,
        'sha' : sha
    }
    response = send_github_api_request(url_tail, 'GET', params=params)
    if "message" in response:
        raise util.GithubAPIFail, response.get('message')
    # end if
    return response
# end function get_commits

def get_branch_lastest_commit(repo, branch):
    url_tail = repo + '/branches/' + branch
    return send_github_api_request(url_tail)['commit']['sha']
# end get_branch_lastest_commit

def get_tag_sha(repo, tag_name):
    """
    Get the sha of given tag name
    Args:
        repo: the repo name
        tag_name: retrieve sha of tag name
    """

    url_tail = repo + '/git/refs/tags'

    response = send_github_api_request(url_tail, 'GET')
    if "message" in response:
        raise util.GithubAPIFail, response.get('message')
    # end if

    for tag in response:
        if tag['ref'] == 'refs/tags/' + tag_name:
            return tag['object']['sha']
        # end if
    # end for

    return None
# end function get_tag_sha

def tag_branch_as_stable(repo, sha, tag_name):
    """
    Create the tag. If it exists, ignore the response. No influence anyway.
    Args:
        repo: the repo to tag
        sha: the commit number
        tag_name: the tag name
    """
    url_tail = repo + '/git/refs'
    data = {
        'ref': "refs/tags/" + tag_name,
        'sha': sha
    }
    response = send_github_api_request(url_tail, 'POST', json.dumps(data), True)
    if "message" in response and response.get("message") != "Reference already exists":
        raise util.AdvanceTagFail, response.get('message')
    # end if

    # Patch the tag
    url_tail = repo + '/git/refs/tags/' + tag_name
    data = {
        'sha': sha,
        'force' : True
    }
    response = send_github_api_request(url_tail, 'POST', json.dumps(data))
    if "message" in response:
        raise util.AdvanceTagFail, response.get('message')
    # end if
    print repo, tag_name + " tag advanced"
# end function tag_branch_as_stable

########### issues api ###########
def open_issue(repo, title, body, labels, **kwargs):
    """
    Open a github issue
    Args:
        repo: the repo to open an issue
        title: issue title
        body: issue content
        labels: issue labels
        **kwargs: other params
    """
    url_tail = repo + '/issues'
    data = {
        'repo': repo,
        'title': title,
        'body': body,
        'labels': labels
    }
    data.update(kwargs)

    response = send_github_api_request(url_tail, 'POST', json.dumps(data), retry=20)
    if "message" in response:
        raise util.OpenIssueFail, response.get('message')
    # end if
# end function open_issue

def get_issues(repo, labels, state):
    """
    Retrieve github issue
    Args:
        repo: the repo name from where to retrieve issues
        labels: only retrieve issues with given labels
        state: only retrieve issues of given state
    Return:
        Array of issues satisfying given conditions
    """
    url_tail = repo + '/issues'
    params = {
        'repo': repo,
        'labels': labels,
        'state': state
    }
    response = send_github_api_request(url_tail, 'GET', params=params, retry=20)
    if "message" in response:
        raise util.OpenIssueFail, response.get('message')
    # end if
    return response
# end function get_issues
