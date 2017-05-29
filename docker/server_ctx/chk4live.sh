#!/bin/sh
ps -ef|grep oninit|grep -v "grep oninit"
exit $?
