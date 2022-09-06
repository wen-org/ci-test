#!/usr/bin/python
import util
from util import send_http_request
import requests, json, time


def send_hipchat_api_request(url_tail, method='GET', data = None, retry=30, retry_interval=60):
    headers = {
        'content-type': 'application/json'
        }
    url = 'https://api.hipchat.com/v2/' + url_tail + '?auth_token=D2FV3WMo6KgJkF61A0PDPCgHYhwXaKLl9gaWRZvF' #label - QA-kevin
    #url = 'https://api.hipchat.com/v2/' + url_tail + '?auth_token=A25BXxpkflMS7Sc9nnbg2cjV0pJGwxGEpZQb76xC' #label - For test purpose
    while retry >= 0:
        try:
            response = send_http_request(url, headers, method, data)
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
        raise util.NotifyFail, response.json()['message']
    # end if
    return response
# end function send_hipchat_api_request

def notify_room(room_name, msg, color, notify = False):
    """
    Notify a room with hipchat message
    Args:
        user_name: username(email address prefix) of hipchat
        msg: message content
        color: messgae display color
        notify: defualt is False. whether to display notification for this message.
    Returns:
        http response result
    """
    url_tail = 'room/' + room_name.replace(' ', '%20') + '/notification'
    data = { 'message': msg, 'notify' : notify, 'message_format': 'html', 'color': color }
    return send_hipchat_api_request(url_tail, 'POST', json.dumps(data))
# end function notify_room

def notify_person(user_name, msg, plain = False):
    """
    Notify a person with hipchat message
    Args:
        user_name: username(email address prefix) of hipchat
        msg: message content
        plain: defualt is False. If it is false, 'message_format' is 'text', otherwise is 'html'
    Returns:
        http response result
    """
    url_tail = 'user/' + user_name + '@tigergraph.com/message'
    data = { 'message': msg, 'notify' : True, 'message_format': 'text' if plain else 'html' }
    return send_hipchat_api_request(url_tail, 'POST', json.dumps(data))
# end function notify_person
