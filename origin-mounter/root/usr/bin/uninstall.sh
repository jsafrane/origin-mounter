#!/bin/sh -x

NAME="origin-mounter"

chroot ${HOST} /usr/bin/systemctl disable ${NAME}.service

rm -f ${HOST}/etc/systemd/system/${NAME}.service
rm -rf ${HOST}/var/lib/origin-mounter

chroot ${HOST} /usr/bin/systemctl daemon-reload
