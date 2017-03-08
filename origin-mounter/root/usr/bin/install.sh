#!/bin/sh -x

# Install systemd unit file for running container
cp etc/systemd/system/origin-mounter.service ${HOST}/etc/systemd/system/origin-mounter.service

# Enabled systemd unit file
chroot ${HOST} /usr/bin/systemctl daemon-reload
chroot ${HOST} /usr/bin/systemctl enable origin-mounter.service

# Install mount helper
mkdir ${HOST}/var/lib/origin-mounter/
cp mounter ${HOST}/var/lib/origin-mounter/
chmod 755  ${HOST}/var/lib/origin-mounter/mounter
