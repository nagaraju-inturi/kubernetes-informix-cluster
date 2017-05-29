FROM centos
MAINTAINER nagaraju@us.ibm.com
ENV INFORMIXDIR /opt/ibm/informix/
ENV LD_LIBRARY_PATH /lib64
RUN mkdir /opt/ibm/  &&  mkdir /opt/ibm/informix
RUN yum -y update && yum -y install libaio sysstat libgcc libstdc compat-libstdc++-33 gcc kernel-headers kernel-devel net-tools.x86_64
RUN /usr/sbin/groupadd -g 102 -f informix
RUN ["/usr/sbin/useradd", "-m", "-g 102", "-u 200", "informix"]
RUN /bin/bash -c 'echo "informix:changeme" | /usr/sbin/chpasswd'
ADD clientsdk.4.10.tar /opt/ibm/informix/
ADD response.txt /tmp/response.txt
RUN /opt/ibm/informix/installclientsdk  -i SILENT -f /tmp/response.txt

USER informix
ADD cmsm_demo.cfg /opt/ibm/informix/etc/
ADD chkinformix.sh /opt/ibm/
ADD chk4live.sh    /opt/ibm/

USER root

WORKDIR /opt/ibm
ENTRYPOINT ["/opt/ibm/boot.sh"]
CMD ["--start"]
EXPOSE 50000
EXPOSE 50001
EXPOSE 50002
EXPOSE 50003
EXPOSE 50004
EXPOSE 50005
ADD boot.sh /opt/ibm/
