# Mount container for Origin

Goal: **remove `mount.glusterfs` (and similar mount utilities) from Atomic Host and run them in a container.** As consequence, any fuse daemon will run in the container too.

## Existing solution

* We ship Atomic Host with all `mount.<fstype>` utilities in the AH image.
* OpenShift node itself runs in a docker container and uses `/var/lib/origin` from the host as a slave bind-mount.
  * OpenShift node inside the container then uses this magic call to mount external volumes to the host, which then get propagated into the OpenShift node container:
        
    ```
    nsenter /host/proc/1/ns/mnt mount -t <fs> <what> /var/lib/origin/openshift.local.volumes/pods/...
    ```

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



# Usage

Quick and dirty notes to try code in this repo.

## Configuration

* Patch origin with `origin-nsenter-helper.patch`, build `openshift/node` container image with it and distribute it to all nodes.

* On all nodes, **remove** or comment out this line in `/lib/systemd/system/docker.service` and restart docker:
  
  ```
  MountFlags=slave
  ```

* On all nodes, build `origin/mounter` container image:
  
  ```
  $ cd origin-mounter
  $ docker build -t origin/mounter .
  ```

* On all nodes, install `origin-mounter.service` from `origin/mounter` image:
  
  ```
  $ atomic install origin/mounter
  $ systemctl start origin-mounter
  ```

* On all nodes, edit node-config.yaml and add:
  
  ```
  kubeletArguments:
    experimental-mounter-path:
    - "/var/lib/origin-mounter/mounter"
  ```
  
  Restart the nodes.

Now create a pod that uses glusterfs and see gluster fuse daemon running inside `origin-mounter` mounter container instead of on the host.

## Update

When a new version of `origin/mounter` is released (via errata?), admin must manually update all nodes one by one:
* Drain a node.
* Update `origin/mounter` image.
* Reboot the node (restart of `origin-mounter` service *could* be enough, however I don't trust docker and shared bind mounts...)

## Future

Once we can export mounts from a pod via shared bind-mount, we can use the same (or very similar) `origin-mounter` container running as a DaemonSet on each node and we can teach Kubernetes to do `docker exec <daemon set member> mount -t <fs> <what> <where>`. We won't depend on `atomic install` creating a service and a mount helper, all would run on any non-atomic system.
