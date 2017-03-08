# Mount container for Origin

Goal: **remove `mount.glusterfs` (and similar mount utilities) from Atomic Host and run them in a container.**

## Existing solution

We ship Atomic Host with all `mount.xyz` utilities that Origin needs in the AH image. OpenShift node itself runs in a docker container and uses `/var/lib/origin` from the host as a slave bind-mount. OpenShift inside the container then uses `nsenter /host/proc/1/ns/mnt mount -t <fs> <what> /var/lib/origin/openshift.local.volumes/pods/...` to mount stuff on the host, which then gets propagated into OpenShift node container.

This requires `mount.<fstype>` to be installed on the host and all fuse daemons also run on the host.

## Assumptions

* **It's currently impossible to use shared mounts in OpenShift pods**. There are issues and PRs that try to add it to Kubernetes, but they're open for ages with very little progress. Once we can expose shared mounts from pods we can forget all the atomic magic below and use better solution with DaemonSet with mount utilities inside.

## Design

* Leverage experimental mount helper (`kubelet --experimental-mounter-path /path/to/mount/helper`) and call `nsenter /host/proc/1/ns/mnt /var/lib/origin-mounter/mounter -t <fs> <what> /var/lib/origin/openshift.local.volumes/pods/...`
* Use an Atomic mount container (say `origin-mounter`) that:
  * Runs as a systemd service (i.e. it's independent on OpenShift).
  * Runs a minimal init inside, all we need is something that reaps zombies of finished fuse daemons.
  * Contains all mount utilities inside.
  * Has `/var/lib/origin` mounted as **shared** bind mount, all things mounted inside the container are visible on the host and in OpenShift node container.
  * Exposes `/var/lib/origin-mount/mounter` on the host (created by `atomic install origin-master`)
    * This `/var/lib/origin-mount/mounter` is a tiny script that just calls `docker exec origin-mounter "$@"` and mount actually happens inside the container.

## Implementation

### Changes in our packages
* Kubernetes must be changed to use mount helper in `nsenter_mount.go`, see a patch lying around.
* Docker service must be changed **not to contain** `MountFlags=slave`
* Create and maintain `origin/mounter` docker image.

### Configuration (ansible scripts?)
* `node-config.yaml` of OpenShift node needs to be changed to contain:
  ```
  kubeletArguments:
    experimental-mounter-path:
    - "/var/lib/origin-mounter/mounter"
  ```
* `atomic install origin/mounter` must be executed on all nodes. It pulls the mounter image from a repository, creates `/var/lib/origin-mount/mounter` and a systemd service that runs the container on boot. After that, either reboot or `systemctl start origin-mounter` is needed.

### Container update

When a new version of `origin/mounter` is released (via errata?), admin must manually update all nodes one by one:
* Drain a node.
* Update `origin/mounter` image.
* Reboot the node (restart of `origin-mounter` service *could* be enough, however I don't trust docker and shared bind mounts...)


## Future

Once we can export mounts from a pod via shared bind-mount, we can use the same (or very similar) `origin-mounter` container running as a DaemonSet on each node and we can teach Kubernetes to do `docker exec <daemon set member> mount -t <fs> <what> <where>`. We won't depend on `atomic install` creating a service and a mount helper, all would run on any non-atomic system.
