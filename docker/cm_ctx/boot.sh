#!/bin/sh 

export INFORMIXDIR=/opt/ibm/informix
export PATH=":${INFORMIXDIR}/bin:.:${PATH}"
export INFORMIXSQLHOSTS="${INFORMIXDIR}/etc/sqlhosts"
export LD_LIBRARY_PATH="${INFORMIXDIR}/lib:${INFORMIXDIR}/lib/esql:${LD_LIBRARY_PATH}"

[[ `hostname` =~ -([0-9]+)$ ]] || exit 1
HOSTIDX=${BASH_REMATCH[1]}

CM_PRI=$((100 + $HOSTIDX))

SLEEP_TIME=1  # Seconds
MAX_SLEEP=240 # Seconds

HOSTNM=`hostname -f`


echoThis()
{
  timestamp=`date --rfc-3339=seconds`
  echo "[$timestamp] $@"
  echo "[$timestamp] $@" >> /tmp/informix.log
}

function clean_up {

    # Perform program exit housekeeping
    echo "${sn} stop: Shutting down CM Instance ..."
    su informix -c "${INFORMIXDIR}/bin/oncmsm -k $CM_NAME"
    echo "${sn} stop: done"
    
    exit 0
}

trap clean_up SIGHUP SIGINT SIGTERM


if [ -f /etc/profile.d/informix.sh ]; then
    . /etc/profile.d/informix.sh
fi
local_ip=`ifconfig eth0 |awk '{if(NR==2)print $2}'`

preStart()
{
setStr="
#!/bin/bash

export INFORMIXDIR=/opt/ibm/informix
export PATH="${INFORMIXDIR}/bin:\${PATH}"
export INFORMIXSERVER=informix0
export INFORMIXSQLHOSTS=\"${INFORMIXSQLHOSTS}\"
export LD_LIBRARY_PATH="${INFORMIXDIR}/lib:${INFORMIXDIR}/lib/esql:${LD_LIBRARY_PATH}"
export CM_NAME=\"${CM_NAME}\"
export TERM=xterm
"
   echo "${setStr}" > /etc/profile.d/informix.sh
   . /etc/profile.d/informix.sh
   chown informix:informix /etc/profile.d/informix.sh
   chmod 644 /etc/profile.d/informix.sh
   echo "g_cluster group - - i=1" >${INFORMIXDIR}/etc/sqlhosts
   echo "informix0 onsoctcp informix-0.informix 60000 g=g_cluster" >>${INFORMIXDIR}/etc/sqlhosts
   echo "informix1 onsoctcp informix-1.informix 60000 g=g_cluster" >>${INFORMIXDIR}/etc/sqlhosts

   chown informix:informix ${INFORMIXDIR}/etc/sqlhosts
   echo "oltp onsoctcp $HOSTNM 50000" >>${INFORMIXDIR}/etc/sqlhosts
   echo "report onsoctcp $HOSTNM 50001" >>${INFORMIXDIR}/etc/sqlhosts
   if [ $SSLCONFIG = "true" ]
   then
       echo "oltp_ssl onsocssl $HOSTNM 50002" >>${INFORMIXDIR}/etc/sqlhosts
       echo "report_ssl onsocssl $HOSTNM 50003" >>${INFORMIXDIR}/etc/sqlhosts
   fi
   echo "oltp_drda drsoctcp $HOSTNM 50004" >>${INFORMIXDIR}/etc/sqlhosts
   echo "report_drda drsoctcp $HOSTNM 50005" >>${INFORMIXDIR}/etc/sqlhosts

   sed -i "s/^NAME.*/NAME   $CM_NAME /g" ${INFORMIXDIR}/etc/cmsm_demo.cfg
   #sed -i "s/^  FOC.*/  FOC  ORDER=ENABLED  PRIORITY=$CM_PRI /g" ${INFORMIXDIR}/etc/cmsm_demo.cfg
   sed -i "s/^  FOC.*/  FOC  ORDER=DISABLED  PRIORITY=$CM_PRI /g" ${INFORMIXDIR}/etc/cmsm_demo.cfg
   if [ $SSLCONFIG = "true" ]
   then
       cp /etc/sslkeysecret/ssl-kdb $INFORMIXDIR/etc/client.kdb
       cp /etc/sslkeysecret/ssl-sth $INFORMIXDIR/etc/client.sth
       chown informix:informix $INFORMIXDIR/etc/client.kdb
       chown informix:informix $INFORMIXDIR/etc/client.sth
       chmod 600 $INFORMIXDIR/etc/client.kdb
       chmod 600 $INFORMIXDIR/etc/client.sth
   else
       sed -i "s/  SLA oltp_ssl.*//g" ${INFORMIXDIR}/etc/cmsm_demo.cfg
       sed -i "s/  SLA report_ssl.*//g" ${INFORMIXDIR}/etc/cmsm_demo.cfg
   fi
   


}

echo $1
case "$1" in
    '--start')
	    if [ -e /etc/profile.d/informix.sh ]; then
                su informix -c "${INFORMIXDIR}/bin/oncmsm -c ${INFORMIXDIR}/etc/cmsm_demo.cfg"  && tail -f ${INFORMIXDIR}/tmp/cm.log
                exit 0
            fi
            CM_NAME=cm$HOSTIDX
            if [ "a$CM_NAME" = "a" ]; then
                CM_NAME="cm1"
             fi
            preStart
            echo "su informix -c \"${INFORMIXDIR}/bin/oncmsm -c ${INFORMIXDIR}/etc/cmsm_demo.cfg\" " >/opt/ibm/start_cm.sh
            echo "su informix -c \"${INFORMIXDIR}/bin/oncmsm -k $CM_NAME\"" >/opt/ibm/stop_cm.sh
            #sleep 5
            sh -x /opt/ibm/start_cm.sh
            echo "${sn} start: done"
            tail -f ${INFORMIXDIR}/tmp/cm.log
        ;;
    '--stop')
            echo "${sn} stop: Shutting down CM ..."
            su informix -c "${INFORMIXDIR}/bin/oncmsm -k $CM_NAME"
            echo "${sn} stop: done"
        ;;

    '--status')
        s="down"
        ps -ef|grep oncmsm|grep -v grep
        if [ $? -eq 0 ]; then
           s="up"
        fi
        echo "${sn} status: CM $CM_NAME Instance is ${s}"
        ;;
    '--shell')
        /bin/bash -c "$2 $3 $4 $5 $6"
        ;;
    *)
        echo "Usage: ${sn} {--start|--stop|--status}"
        ;;
esac

exit 0
