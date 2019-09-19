#!/bin/sh

export INFORMIXDIR=/opt/ibm/informix
export PATH=":${INFORMIXDIR}/bin:.:${PATH}"
#export INFORMIXSERVER=informix
export INFORMIXSQLHOSTS="${INFORMIXDIR}/etc/sqlhosts"
export ONCONFIG=onconfig
export LD_LIBRARY_PATH="${INFORMIXDIR}/lib:${INFORMIXDIR}/lib/esql:${LD_LIBRARY_PATH}"
export DATA_ROOT="${DATA_ROOT:-/opt/ibm/data/}"

[[ `hostname` =~ -([0-9]+)$ ]] || exit 1
HOSTIDX=${BASH_REMATCH[1]}
DOMAIN=`hostname -f |cut -d'.' -f2,3,4,5,6,7,8`
CMDOMAIN=`hostname -f |cut -d'.' -f3,3,4,5,6,7,8`

CMHOSTPREFIX=cm
SLEEP_TIME=1  # Seconds
MAX_SLEEP=240 # Seconds


echoThis()
{
  timestamp=`date --rfc-3339=seconds`
  echo "[$timestamp] $@"
  echo "[$timestamp] $@" >> /tmp/informix.log
}

function clean_up {

    # Perform program exit housekeeping
    echo "${sn} stop: Shutting down informix Instance ..."
    su informix -c "${INFORMIXDIR}/bin/onmode -kuy"
    echo "${sn} stop: done"
    
    exit 0
}

trap clean_up SIGHUP SIGINT SIGTERM


if [ -f /etc/profile.d/informix.sh ]; then
    . /etc/profile.d/informix.sh
elif [ -f ${DATA_ROOT}/config/informix.sh ]; then
    cp ${DATA_ROOT}/config/informix.sh /etc/profile.d/informix.sh
    chown informix:informix /etc/profile.d/informix.sh
    chmod 644 /etc/profile.d/informix.sh
    . /etc/profile.d/informix.sh
    cp ${DATA_ROOT}/config/sqlhosts ${INFORMIXDIR}/etc/
    chown informix:informix ${INFORMIXDIR}/etc/sqlhosts
    chmod 644 ${INFORMIXDIR}/etc/sqlhosts
    cp ${DATA_ROOT}/config/onconfig ${INFORMIXDIR}/etc/
    chown informix:informix ${INFORMIXDIR}/etc/onconfig
    chmod 644 ${INFORMIXDIR}/etc/onconfig
    cp ${DATA_ROOT}/config/authfile ${INFORMIXDIR}/etc/
    chown root:informix ${INFORMIXDIR}/etc/authfile
    chmod 660 ${INFORMIXDIR}/etc/authfile
fi
local_ip=`ifconfig eth0 |awk '{if(NR==2)print $2}'`

preStart()
{
setStr="
#!/bin/bash

export INFORMIXDIR=/opt/ibm/informix
export PATH="${INFORMIXDIR}/bin:\${PATH}"
export INFORMIXSERVER=\"${HA_ALIAS}\"
export HA_ALIAS=\"${HA_ALIAS}\"
export INFORMIXSQLHOSTS=\"${INFORMIXSQLHOSTS}\"
export ONCONFIG=\"onconfig\"
export LD_LIBRARY_PATH="${INFORMIXDIR}/lib:${INFORMIXDIR}/lib/esql:${LD_LIBRARY_PATH}"
export TERM=xterm
"
   echo "${setStr}" > /etc/profile.d/informix.sh
   . /etc/profile.d/informix.sh
   chown informix:informix /etc/profile.d/informix.sh
   chmod 644 /etc/profile.d/informix.sh
   #chown informix:informix ${INFORMIXDIR}/etc/sqlhosts
   touch ${INFORMIXDIR}/etc/authfile
   chown root:informix ${INFORMIXDIR}/etc/authfile
   chmod 660 ${INFORMIXDIR}/etc/authfile
   sed -i "s/DBSERVERNAME.*/DBSERVERNAME $HA_ALIAS /g" ${INFORMIXDIR}/etc/$ONCONFIG
   if [ $SSLCONFIG = "true" ] 
   then
       sed -i "s/DBSERVERALIASES.*/DBSERVERALIASES  ${HA_ALIAS}_ssl,${HA_ALIAS}_drda/g" ${INFORMIXDIR}/etc/$ONCONFIG
   else
       sed -i "s/DBSERVERALIASES.*/DBSERVERALIASES  ${HA_ALIAS}_drda/g" ${INFORMIXDIR}/etc/$ONCONFIG
   fi
   sed -i "s/SSL_KEYSTORE_LABEL.*/SSL_KEYSTORE_LABEL  informix/g" ${INFORMIXDIR}/etc/$ONCONFIG
   sed -i "s/HA_ALIAS.*/HA_ALIAS $HA_ALIAS/g " ${INFORMIXDIR}/etc/$ONCONFIG
   sed -i "s/REMOTE_SERVER_CFG.*/REMOTE_SERVER_CFG authfile/g " ${INFORMIXDIR}/etc/$ONCONFIG
   sed -i "s/NS_CACHE.*/NS_CACHE host=0,service=0,user=900,group=900/g " ${INFORMIXDIR}/etc/$ONCONFIG
   sed -i "s/ROOTPATH.*/ROOTPATH \/opt\/ibm\/data\/dbspaces\/rootdbs /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/MSGPATH.*/MSGPATH \/opt\/ibm\/data\/log\/$HA_ALIAS.log /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/FULL_DISK_INIT.*/FULL_DISK_INIT 1 /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/LOG_INDEX_BUILDS.*/LOG_INDEX_BUILDS 1 /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/TEMPTAB_NOLOG.*/TEMPTAB_NOLOG 1 /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/ENABLE_SNAPSHOT_COPY.*/ENABLE_SNAPSHOT_COPY 1 /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/CDR_AUTO_DISCOVER.*/CDR_AUTO_DISCOVER 1 /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/CDR_QDATA_SBSPACE.*/CDR_QDATA_SBSPACE ersbsp /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/LTAPEDEV.*/LTAPEDEV \/dev\/null /g" /opt/ibm/informix//etc/onconfig
   sed -i "s/VPCLASS cpu/VPCLASS cpu=2,noage/g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/SDS_PAGING.*/SDS_PAGING \/opt\/ibm\/data\/ifx_sds_paging1_$HA_ALIAS,\/opt\/ibm\/data\/ifx_sds_paging2_$HA_ALIAS /g" ${INFORMIXDIR}/etc/onconfig
   sed -i "s/SDS_TEMPDBS.*/SDS_TEMPDBS ifx_sds_tmpdbs_$HA_ALIAS,\/opt\/ibm\/data\/ifx_sds_tmpdbs_$HA_ALIAS,4,0,50M /g" ${INFORMIXDIR}/etc/onconfig
   if [ $SSLCONFIG = "true" ] 
   then
     echo "NETTYPE socssl,3,50,NET" >> ${INFORMIXDIR}/etc/onconfig
     echo "VPCLASS encrypt,num=3" >> ${INFORMIXDIR}/etc/onconfig
   fi

   chown informix:informix ${INFORMIXDIR}/etc/onconfig
   mkdir -p ${DATA_ROOT}/dbspaces
   mkdir -p ${DATA_ROOT}/config
   touch ${DATA_ROOT}/dbspaces/rootdbs
   chown -R informix:informix ${DATA_ROOT}
   chmod 660 ${DATA_ROOT}/dbspaces/rootdbs
   su informix -c "mkdir -p ${DATA_ROOT}/log"
   su informix -c "touch ${DATA_ROOT}/log/$HA_ALIAS.log"
}


# Wait for local server to be On-Line.
wait4online()
{
retry=0
wait4online_status=0
while [ 1 ]
    do
    sleep 10
    onstat -
    server_state=$?

    #Offline mode
    if [ $server_state -eq 255 ]
    then
        wait4online_status=1
        printf "ERROR: wait4online() Server is in Offline mode\n" 
        break
    fi

    # Quiescent mode check.
    # Note: at secondary server, exit code 2 used for Quiscent mode as well.
    if [ $server_state -eq 1 ] || [ $server_state -eq 2 ]
    then
        su -p informix -c 'onmode -m; exit $?'
        onmode_rc=$?
        printf "CMD: onmode -m, exit code $onmode_rc \n" 
        if [  $server_state -ne 2 ]
        then
            printf "INFO: wait4online() Server state changed from Quiescent to On-Line mode\n" 
        fi
    fi
    #Check if sqlexec connectivity is enabled or not.
    onstat -g ntd|grep sqlexec|grep yes
    exit_status=$?
    if [ $exit_status -eq 0 ]
    then
        su informix -c "${INFORMIXDIR}/bin/dbaccess sysadmin - <<EOF
EOF"
        rc=$?
        if [ $rc -eq 0 ]
        then
           wait4online_status=0
           break
        fi
    fi
    retry=$(expr $retry + 1)
    if [ $retry -eq 120 ]
    then
       wait4online_status=1
       printf "ERROR: wait4online() Timed-out waiting for server to allow client connections\n" 
       break
    fi
done
}

#wait for peer server to be in On-Line state.
wait4peer()
{
wait4peer_status=0
retry=0
while [ 1 ]
do
    su informix -c 'export INFORMIXCONTIME=10; dbaccess sysmaster@informix0 - <<EOF
EOF
    exit $?'
    wait4peer_status=$?
    if [ $wait4peer_status  -eq 0 ]
    then
        break;
    fi

    sleep 10
    retry=$(expr $retry + 1)
    if [ $retry -eq 30 ]
    then
       printf "ERROR: wait4peer() Timed-out waiting for peer server informix0 to be On-Line. \n" >> $MAILBODY
       break
    fi
done
}


echo $1
case "$1" in
    '--start')
        if [ `${INFORMIXDIR}/bin/onstat 2>&- | grep -c On-Line` -ne 1 ]; then
            if [ ! -f ${DATA_ROOT}/dbspaces/rootdbs ]; then
               HA_ALIAS=informix$HOSTIDX
               preStart
               echo "informix-0" >${INFORMIXDIR}/etc/authfile
               echo "informix-0.informix" >>${INFORMIXDIR}/etc/authfile
               echo "informix-0.$DOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "informix-1" >>${INFORMIXDIR}/etc/authfile
               echo "informix-1.informix" >>${INFORMIXDIR}/etc/authfile
               echo "informix-1.$DOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "informix-2" >>${INFORMIXDIR}/etc/authfile
               echo "informix-2.informix" >>${INFORMIXDIR}/etc/authfile
               echo "informix-2.$DOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-0" >>${INFORMIXDIR}/etc/authfile
               echo "cm-0.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-0.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-1" >>${INFORMIXDIR}/etc/authfile
               echo "cm-1.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-1.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-2" >>${INFORMIXDIR}/etc/authfile
               echo "cm-2.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-2.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-3" >>${INFORMIXDIR}/etc/authfile
               echo "cm-3.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-3.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-4" >>${INFORMIXDIR}/etc/authfile
               echo "cm-4.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-4.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile
               echo "cm-5" >>${INFORMIXDIR}/etc/authfile
               echo "cm-5.cm" >>${INFORMIXDIR}/etc/authfile
               echo "cm-5.cm.$CMDOMAIN" >>${INFORMIXDIR}/etc/authfile

               echo "informix0 onsoctcp informix-0.$DOMAIN 60000" >${INFORMIXDIR}/etc/sqlhosts
               echo "informix1 onsoctcp informix-1.$DOMAIN  60000" >>${INFORMIXDIR}/etc/sqlhosts
               echo "informix2 onsoctcp informix-2.$DOMAIN 60000" >>${INFORMIXDIR}/etc/sqlhosts

               if [ $SSLCONFIG = "true" ] 
               then
                   echo "informix0_ssl onsocssl  informix-0.$DOMAIN 60001" >>${INFORMIXDIR}/etc/sqlhosts
                   echo "informix1_ssl onsocssl  informix-1.$DOMAIN  60001" >>${INFORMIXDIR}/etc/sqlhosts
                   echo "informix2_ssl onsocssl  informix-2.$DOMAIN 600001" >>${INFORMIXDIR}/etc/sqlhosts
               fi

               echo "informix0_drda drsoctcp  informix-0.$DOMAIN 60002" >>${INFORMIXDIR}/etc/sqlhosts
               echo "informix1_drda drsoctcp  informix-1.$DOMAIN  60002" >>${INFORMIXDIR}/etc/sqlhosts
               echo "informix2_drda drsoctcp  informix-2.$DOMAIN 600002" >>${INFORMIXDIR}/etc/sqlhosts

               if [ $SSLCONFIG = "true" ] 
               then
                   cp /etc/sslkeysecret/ssl-kdb $INFORMIXDIR/ssl/$INFORMIXSERVER.kdb
                   cp /etc/sslkeysecret/ssl-sth $INFORMIXDIR/ssl/$INFORMIXSERVER.sth
                   chown informix:informix $INFORMIXDIR/ssl/$INFORMIXSERVER.kdb
                   chown informix:informix $INFORMIXDIR/ssl/$INFORMIXSERVER.sth
                   chmod 600 $INFORMIXDIR/ssl/$INFORMIXSERVER.kdb
                   chmod 600 $INFORMIXDIR/ssl/$INFORMIXSERVER.sth
                   su informix -c "ln -s $INFORMIXDIR/ssl/$INFORMIXSERVER.kdb $INFORMIXDIR/etc/client.kdb"
                   su informix -c "ln -s $INFORMIXDIR/ssl/$INFORMIXSERVER.sth $INFORMIXDIR/etc/client.sth"
               fi
               cp /etc/profile.d/informix.sh ${DATA_ROOT}/config/
               cp ${INFORMIXDIR}/etc/sqlhosts  ${DATA_ROOT}/config/
               cp ${INFORMIXDIR}/etc/authfile  ${DATA_ROOT}/config/
               cp ${INFORMIXDIR}/etc/onconfig  ${DATA_ROOT}/config/

	       if [[ "$HOSTIDX" -eq 1 ]]; then
                  echo " su informix -c \"ifxclone -S informix0 -I informix-0.$DOMAIN -P 60000 -t $HA_ALIAS -i informix-$HOSTIDX.$DOMAIN -p 60000 -L -T -d HDR -k \" " >/opt/ibm/clone.sh
                  echo "sleep  30" >>/opt/ibm/clone.sh
	       fi
	       if [[ "$HOSTIDX" -ge 2 ]]; then
                  echo " su informix -c \"ifxclone -S informix0 -I informix-0 -P 60000 -t $HA_ALIAS -i informix-$HOSTIDX -p 60000 -L -T -d RSS -k \" " >/opt/ibm/clone.sh
                  echo "sleep  30" >>/opt/ibm/clone.sh
	       fi
               if [[ "$HOSTIDX" -eq 0 ]]; then
                   su informix -c "oninit -ivy" 
                   wait4online
	           sleep 5
                   su informix -c "${INFORMIXDIR}/bin/dbaccess sysadmin@informix0 - <<EOF
                   EXECUTE FUNCTION task(\"storagepool add\",\"/opt/ibm/data/dbspaces\", \"0\", \"0\", \"20000\", \"1\");
EOF" 
                   tail -f  ${DATA_ROOT}/log/$HA_ALIAS.log
               else
                   sleep 30
                   wait4peer
                   sleep 30
                   sh -x /opt/ibm/clone.sh
                   wait4online
#                   if [[ "$HOSTIDX" -eq 1 ]]; then
#                       wait4online
#                       su informix -c "${INFORMIXDIR}/bin/dbaccess sysadmin@informix0 - <<EOF
#                       EXECUTE FUNCTION task(\"ha rss delete\",\"$HA_ALIAS\");
#EOF" 
#                    fi
                   tail -f  ${DATA_ROOT}/log/$HA_ALIAS.log
               fi
            else
	        if [[ "$HOSTIDX" -ne 0 ]]; then
                   wait4peer
                fi
                su informix -c "${INFORMIXDIR}/bin/oninit -vy" 
                tail -f  ${DATA_ROOT}/log/$HA_ALIAS.log
            fi
            echo "${sn} start: done"
            /bin/bash
        fi
        ;;
    '--stop')
        if [ `$INFORMIXDIR/bin/onstat 2>&- | grep -c On-Line` -eq 1 ]; then
            echo "${sn} stop: Shutting down informix Instance ..."
            su informix -c "${INFORMIXDIR}/bin/onmode -kuy"
            echo "${sn} stop: done"
        fi
        ;;

    '--status')
        s="down"
        if [ `${INFORMIXDIR}/bin/onstat 2>&- | grep -c On-Line` -eq 1 ]; then
            s="up"
        fi
        echo "${sn} status: informix Instance is ${s}"
        ;;
    '--shell')
        /bin/bash -c "$2 $3 $4 $5 $6"
        ;;
    *)
        echo "Usage: ${sn} {--start|--stop|--status}"
        ;;
esac

exit 0
