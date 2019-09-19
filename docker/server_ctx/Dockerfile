FROM centos
MAINTAINER nagaraju.inturi@hcl.com
ENV INFORMIXDIR /opt/ibm/informix/
ENV LD_LIBRARY_PATH /lib64
RUN mkdir /opt/ibm/  &&  mkdir /opt/ibm/informix
#VOLUME ["/opt/ibm/informix/", "/opt/ibm/data/"]
VOLUME ["/opt/ibm/data/"]
RUN yum -y update && yum -y install libaio sysstat libgcc libstdc compat-libstdc++-33 gcc kernel-headers kernel-devel net-tools.x86_64
RUN /usr/sbin/groupadd -g 102 -f informix
RUN ["/usr/sbin/useradd", "-m", "-g 102", "-u 200", "informix"]
RUN /bin/bash -c 'echo "informix:changeme" | /usr/sbin/chpasswd'
ADD IIF.14.10.tar /opt/ibm/informix/
ADD bundle.properties /tmp/bundle.properties
RUN /opt/ibm/informix/ids_install -i silent -f /tmp/bundle.properties
RUN /bin/bash -c 'chown informix:informix /opt/ibm/data/'
RUN /bin/bash -c '/bin/rm -rf /opt/ibm/informix/ids_install /opt/ibm/informix/IBM_Data_Server_Driver_Package /opt/ibm/informix/CSDK /opt/ibm/informix/ICONNECT /opt/ibm/informix/JDBC /opt/ibm/informix/SDK /opt/ibm/informix/SERVER'

USER informix
RUN /bin/bash -c 'cp /opt/ibm/informix//etc/onconfig.std /opt/ibm/informix//etc/onconfig'
#RUN /bin/bash -c 'cp /opt/ibm/informix//etc/sqlhosts.std /opt/ibm/informix//etc/sqlhosts'
ADD chkinformix.sh /opt/ibm/
ADD chk4live.sh /opt/ibm/

USER root

WORKDIR /opt/ibm
ENTRYPOINT ["/opt/ibm/boot.sh"]
CMD ["--start"]
EXPOSE 60000
EXPOSE 60001
EXPOSE 60002
ADD boot.sh /opt/ibm/
