# quay-registry
Use [RedHat mirror-registry package](https://docs.openshift.com/container-platform/4.14/installing/disconnected_install/installing-mirroring-creating-registry.html) to create a Quay container registry.  <br>
This registry package deployment process uses podman to deploy containers. [quay-registry](quay-registry.sh)  <br>

Recommend adding LetsEncrypt certs to avoid browser TLS challenges with self-signed certs. <br>
Recommend that the workstation/server have free disk space > 350-1000 GB to host OpenShift containers and others within the registry


[mirror-registry.tar.gz](https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz)<br>


![image](https://github.com/anapartner-com/quay-registry/assets/51460618/9b3e6426-d4fc-4e62-b29b-e8be01f0f72d)


### View of running containers
![image](https://github.com/anapartner-com/quay-registry/assets/51460618/10a53ef0-dfc7-452a-b09a-4ab44e332340)

### Start and stop containers with 'systemctl' processes
```
View systemctl processes created for all three (3) containers: (example below for quay-app container)

 systemctl stop   quay-app.service
 systemctl start  quay-app.service
 systemctl status quay-app.service
 systemctl cat    quay*.service --no-pager
```


### To replace TLS certs, stop/start the primary container:

```
 systemctl stop quay-app.service
 cp -r -p new_cert.pem ${REGISTRY_FOLDER}/quay-config/ssl.cert
 cp -r -p new_ssl.key  ${REGISTRY_FOLDER}/quay-config/ssl.key
 systemctl start quay-app.service
 systemctl status quay-app.service --no-pager
```


### View of the systemctl services
systemctl cat    quay*.service --no-pager <br>
```
# /etc/systemd/system/quay-postgres.service
[Unit]
Description=PostgreSQL Podman Container for Quay
Wants=network.target
After=network-online.target quay-pod.service
Requires=quay-pod.service

[Service]
Type=simple
TimeoutStartSec=5m
ExecStartPre=-/bin/rm -f %t/%n-pid %t/%n-cid
ExecStart=/usr/bin/podman run \
    --name quay-postgres \
    -v pg-storage:/var/lib/pgsql/data:Z \
    -e POSTGRESQL_USER=user \
    -e POSTGRESQL_PASSWORD=password \
    -e POSTGRESQL_DATABASE=quay \
    --pod=quay-pod \
    --conmon-pidfile %t/%n-pid \
    --cidfile %t/%n-cid \
    --cgroups=no-conmon \
    --replace \
    registry.redhat.io/rhel8/postgresql-10:1-203.1669834630

ExecStop=/usr/bin/podman stop --ignore --cidfile %t/%n-cid -t 10
ExecStopPost=/usr/bin/podman rm --ignore -f --cidfile %t/%n-cid
PIDFile=%t/%n-pid
KillMode=none
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target default.target

# /etc/systemd/system/quay-app.service
[Unit]
Description=Quay Container
Wants=network.target
After=network-online.target quay-pod.service quay-postgres.service quay-redis.service
Requires=quay-pod.service quay-postgres.service quay-redis.service

[Service]
Type=simple
TimeoutStartSec=5m
ExecStartPre=-/bin/rm -f %t/%n-pid %t/%n-cid
ExecStart=/usr/bin/podman run \
    --name quay-app \
    -v /media/mirror-registry/quay-config:/quay-registry/conf/stack:Z \
    -v quay-storage:/datastorage:Z \
    --pod=quay-pod \
    --conmon-pidfile %t/%n-pid \
    --cidfile %t/%n-cid \
    --cgroups=no-conmon \
    --replace \
    registry.redhat.io/quay/quay-rhel8:v3.8.14

ExecStop=-/usr/bin/podman stop --ignore --cidfile %t/%n-cid -t 10
ExecStopPost=-/usr/bin/podman rm --ignore -f --cidfile %t/%n-cid
PIDFile=%t/%n-pid
KillMode=none
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target default.target

# /etc/systemd/system/quay-pod.service
[Unit]
Description=Infra Container for Quay
Wants=network.target
After=network-online.target
Before=quay-postgres.service quay-redis.service

[Service]
Type=simple
RemainAfterExit=yes
TimeoutStartSec=5m
ExecStartPre=-/bin/rm -f %t/%n-pid %t/%n-pod-id
ExecStart=/usr/bin/podman pod create \
    --name quay-pod \
    --infra-image registry.access.redhat.com/ubi8/pause:8.7-6 \
    --publish 443:8443 \
    --pod-id-file %t/%n-pod-id \
    --replace
ExecStop=-/usr/bin/podman pod stop --ignore --pod-id-file %t/%n-pod-id -t 10
ExecStopPost=-/usr/bin/podman pod rm --ignore -f --pod-id-file %t/%n-pod-id
PIDFile=%t/%n-pid
KillMode=none
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target default.target


# /etc/systemd/system/quay-redis.service
[Unit]
Description=Redis Podman Container for Quay
Wants=network.target
After=network-online.target quay-pod.service
Requires=quay-pod.service

[Service]
Type=simple
TimeoutStartSec=5m
ExecStartPre=-/bin/rm -f %t/%n-pid %t/%n-cid
ExecStart=/usr/bin/podman run \
    --name quay-redis \
    -e REDIS_PASSWORD=password \
    --pod=quay-pod \
    --conmon-pidfile %t/%n-pid \
    --cidfile %t/%n-cid \
    --cgroups=no-conmon \
    --replace \
    registry.redhat.io/rhel8/redis-6:1-92.1669834635

ExecStop=-/usr/bin/podman stop --ignore --cidfile %t/%n-cid -t 10
ExecStopPost=-/usr/bin/podman rm --ignore -f --cidfile %t/%n-cid
PIDFile=%t/%n-pid
KillMode=none
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target default.target
```


### View of embedded images within "mirror-registry" package
![image](https://github.com/anapartner-com/quay-registry/assets/51460618/fbaf028d-d1a8-4862-b2b1-e1538934ca69)

### View of the embedded podman using ansible_runner_instance container with an ansible-playbook  (seen with verbose mode -v with mirror-registry deployment)

```podman run --rm --interactive --tty --workdir /runner/project --net host -v /media/openshift-offline/image-archive.tar:/runner/image-archive.tar -v /root/labs/letsencrypt/combined_chain_with_cert.pem:/runner/certs/quay.cert:Z -v /root/labs/letsencrypt/privkey.pem:/runner/certs/quay.key:Z -v /root/.ssh/quay_installer:/runner/env/ssh_key -e RUNNER_OMIT_EVENTS=False -e RUNNER_ONLY_FAILED_EVENTS=False -e ANSIBLE_HOST_KEY_CHECKING=False -e ANSIBLE_CONFIG=/runner/project/ansible.cfg -e ANSIBLE_NOCOLOR=false --quiet --name ansible_runner_instance quay.io/quay/mirror-registry-ee:latest ansible-playbook -i root@registry.ocp.anapartner.dev, --private-key /runner/env/ssh_key -e "init_user=init init_password=Password01 quay_image=registry.redhat.io/quay/quay-rhel8:v3.8.10 quay_version=v3.8.10 redis_image=registry.redhat.io/rhel8/redis-6:1-92.1669834635 postgres_image=registry.redhat.io/rhel8/postgresql-10:1-203.1669834630 pause_image=registry.access.redhat.com/ubi8/pause:8.7-6 quay_hostname=registry.ocp.anapartner.dev:8443 local_install=true quay_root=/media/mirror-registry quay_storage=quay-storage pg_storage=pg-storage" install_mirror_appliance.ym```


### Warning messages to ignore (seen when using verbose mode)

![image](https://github.com/anapartner-com/quay-registry/assets/51460618/4e7b3fcf-d495-42d8-9b99-d9eb0dbf4bdd)

### Error message due to unused container volumes (need clean up)<br>
"allocating lock for new volume: allocation failed; exceeded num_locks"

![image](https://github.com/anapartner-com/quay-registry/assets/51460618/44ff77ed-5f90-43eb-974f-3e07ade2c6c9)

