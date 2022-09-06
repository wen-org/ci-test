#!/usr/bin/python
import util
from util import send_http_request_auth
import requests, json, urllib, time

def send_jira_api_request(url_tail, method='GET', data = None, retry=30, retry_interval=60):
    headers = {
        'content-type': 'application/json'
        }
    url = 'https://grAphsqL.atlassian.net/rest/api/2/' + url_tail
    while retry >= 0:
        try:
            response = send_http_request_auth(url, headers, method, data, user_name = 'qa', password = 'qa.graphsql.2016')
            break
        except requests.exceptions.ConnectionError:
            print ("Unable to connect to github, retrying in {} seconds".format(retry_interval))
            time.sleep(retry_interval)
            retry -= 1
            if retry < 0:
                print ("Failed to connect to github, request aborted.")
                raise requests.exceptions.ConnectionError

    if response.status_code >= 400:
        print response.json()
        print(response.text)
        raise util.NotifyFail, response.json()['message']
    # end if
    return response
# end function send_jira_api_request

def open_issue(project, issue_type, issue_label, summary, description, assignee):
    """
    Open a bug ticket in jira with the given parameters
    Args:
        project: The project name to open the ticket in (eq QA, GLE ...)
        issue_type: issue type
        issue_label: Labels to be added to the ticket in string format.
                     Multiple labels should be seperated by a space (e.g. "label1 label2 ...")
        summary: The summary for the issue to open
        description: The description for the issue to open
        assignee: The person to assign the issue to.
    """
    url_tail = 'issue'
    data = { \
        "fields": { \
           "project": { "key": project }, \
           "summary": summary, \
           "description": description, \
           "issuetype": { "name": issue_type }, \
           "assignee": { "name": assignee }, \
           "labels": issue_label.split() \
       } \
    }

    return send_jira_api_request(url_tail, 'POST', json.dumps(data))
# end open_issue


def get_open_issues(project, issue_type, issue_label):
    """
    Get open issues of JIRA which status is Open, Reopened or In Progress
    Args:
        project: project name
        issue_type: issue type
        issue_label: issue labels in string format.
                     Multiple labels should be seperated by a space (e.g. "label1 label2 ...")
    Returns:
        An array of issues
    """
    # Search query in JQL to seach for all open QA bug tickets with the given label "issue_label"
    url_tail = 'search?jql=' + urllib.quote_plus('project=' + project + \
            ' AND issuetype= ' + issue_type + ' AND labels in (' + issue_label + \
            ') AND (status=Open OR status=Reopened OR status="In Progress")')
    return send_jira_api_request(url_tail, 'GET', None).json().get('issues')
# end get_open_issues
