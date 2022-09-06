#!/usr/bin/python

from issue_manager import main as issue_checker
import os, time

color = {"red": "KEY_0", "green": "KEY_1"}
sleep_time = 10 # in seconds

def is_blocking():
    """
    return true if there is blocking issues
    """
    flag = False
    try:
        issue_checker([__file__, 'check', 'QA', 'Bug', 'QA_HOURLY_FAILURE'])
        print("green")
    except:
        flag = True
        print("red")
    return flag

"""
call issue_checker every sleep_time.
If there are open QA issues with 'Fault' label, turn color to red
otherwise set color to green
"""
while True:
    key_name = color['red'] if is_blocking() else color['green']
    os.system("irsend SEND_ONCE /home/pi/lircd0.conf {}".format(key_name))
    time.sleep(sleep_time)
