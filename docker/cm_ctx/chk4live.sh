#!/bin/sh
ps -ef|grep oncmsm|grep -v "grep oncmsm"
exit $?
