#!/bin/sh -x
rc=0
su informix -c 'export INFORMIXCONTIME=20; . /etc/profile.d/informix.sh;  dbaccess sysmaster - <<EOF
EOF'
rc=$?
exit $rc
