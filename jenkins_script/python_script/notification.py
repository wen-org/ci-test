#!/usr/bin/python
import util
import sys, os.path, json

def send_hipchat_notification(body, user_name, room_name, color, notify = False):
    if user_name != None:
        util.notify_person(user_name, body)
    # end if
    if room_name != None:
        util.notify_room(room_name, body, color, notify = notify)
    # end if
# end function send_hipchat_notification

def test_pass_notification(repo_dict, user_name, room_name, msg):
    send_hipchat_notification(msg, user_name, room_name, 'green')
    for repo, num in repo_dict.iteritems():
        util.push_comment_to_pull_request(repo, num, msg, util.STATE.APPROVE, silent = True)
    # end for
# end function test_pass_notification

def test_fail_notification(repo_dict, user_name, room_name, msg):
    send_hipchat_notification(msg, user_name, room_name, 'red', True)
    for repo, num in repo_dict.iteritems():
        util.push_comment_to_pull_request(repo, num, msg, util.STATE.REQUEST_CHANGES)
    # end for
# end function test_fail_notification

def test_start_notification(repo_dict, user_name, room_name, msg):
    send_hipchat_notification(msg, user_name, room_name, 'yellow')
    for repo, num in repo_dict.iteritems():
        util.push_comment_to_pull_request(repo, num, msg, util.STATE.COMMENT)
    # end for
# end function test_start_notification

def test_status_notification(repo_dict, user_name, room_name, msg):
    send_hipchat_notification(msg, user_name, room_name, 'purple')
    for repo, num in repo_dict.iteritems():
        util.push_comment_to_pull_request(repo, num, msg, util.STATE.COMMENT)
    # end for
# end function test_status_notification

def main(parameters):
    util.check(len(parameters) >= 5, RuntimeError,
        "Invalid arguments: " + str(parameters[1:]))

    dict = util.parse_parameter(parameters, 1)

    state = parameters[2]
    user_name = parameters[3]
    if user_name == 'none':
        user_name = None
    # end if

    room_name = parameters[4]
    if room_name == 'none':
        room_name = None
    # end if

    msg_json = json.loads(parameters[5])
    msg = '<p><a href="%s">%s</a>  %s</p>' %(msg_json['url'], msg_json['name'], state)
    if 'Reason' in msg_json:
        msg += '<p>%s:  %s</p>' %('Reason', msg_json['Reason'])
    msg += '<p>Jenkins Job:  <a href="%s">Check jenkins job</a></p>' %(msg_json['url'])
    for title, content in msg_json.iteritems():
        if content and title not in ["name", "url", "Reason", "Comment"]:
            msg += '<p>%s:  %s</p>' %(title, content)
    if 'Comment' in msg_json:
        msg += '<p>%s:  %s</p>' %('Comment', msg_json['Comment'])

    if state == 'START':
        test_start_notification(dict, user_name, room_name, msg)

    elif state == 'STATUS':
        test_status_notification(dict, user_name, room_name, msg)

    elif state == 'PASS':
        test_pass_notification(dict, user_name, room_name, msg)

    elif state == 'FAIL':
        test_fail_notification(dict, user_name, room_name, msg)

    else:
        raise RuntimeError, "Invalid argument: " + state
    # end if
# end function main

##############################################
# Arguments:
#   0: this script name
#   1: jenkins parameters, include repo name and pull request number
#   2: notification state: START STATUS PASS FAIL
#   3: user name. If not send to a user, use 'none'
#   4: room name. If not send to a room, use 'none'
#   5: addition message (optional)
##############################################
if __name__ == "__main__":
    main(sys.argv)
