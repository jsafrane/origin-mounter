FROM        fedora:25
MAINTAINER  Jan Safranek
ENV container docker
RUN yum -y update; yum -y install glusterfs-fuse nfs-utils busybox; yum clean all

LABEL INSTALL="docker run --rm --privileged -v /:/host -e HOST=/host -e LOGDIR=/var/log/\${NAME} -e CONFDIR=/etc/\${NAME} -e DATADIR=/var/lib/\${NAME} -e IMAGE=\${IMAGE} -e NAME=\${NAME} \${IMAGE} /usr/bin/install.sh"
LABEL UNINSTALL=" docker run --rm --privileged -v /:/host -e HOST=/host -e IMAGE=${IMAGE} -e NAME=${NAME} ${IMAGE:-origin/mounter} /usr/bin/uninstall.sh"
ADD root /

# We need something to reap zombies
CMD [ "/sbin/busybox", "init" ]
