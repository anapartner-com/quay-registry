# quay-registry
Use RedHat mirror-registry package to create a Quay container registry.  
Recommend adding LetsEncrypt certs to avoid TLS issues with self-signed certs.

wget -nv -N  https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz



![image](https://github.com/anapartner-com/quay-registry/assets/51460618/9b3e6426-d4fc-4e62-b29b-e8be01f0f72d)


View of running containers
![image](https://github.com/anapartner-com/quay-registry/assets/51460618/10a53ef0-dfc7-452a-b09a-4ab44e332340)

View of embedded images within "mirror-registry" package
![image](https://github.com/anapartner-com/quay-registry/assets/51460618/fbaf028d-d1a8-4862-b2b1-e1538934ca69)

View of the embedded podman deployment using ansible_runner_instance container with an ansible-playbook  (seen with verbose mode -v with mirror-registry deployment)

```podman run --rm --interactive --tty --workdir /runner/project --net host -v /media/openshift-offline/image-archive.tar:/runner/image-archive.tar -v /root/labs/letsencrypt/combined_chain_with_cert.pem:/runner/certs/quay.cert:Z -v /root/labs/letsencrypt/privkey.pem:/runner/certs/quay.key:Z -v /root/.ssh/quay_installer:/runner/env/ssh_key -e RUNNER_OMIT_EVENTS=False -e RUNNER_ONLY_FAILED_EVENTS=False -e ANSIBLE_HOST_KEY_CHECKING=False -e ANSIBLE_CONFIG=/runner/project/ansible.cfg -e ANSIBLE_NOCOLOR=false --quiet --name ansible_runner_instance quay.io/quay/mirror-registry-ee:latest ansible-playbook -i root@registry.ocp.anapartner.dev, --private-key /runner/env/ssh_key -e "init_user=init init_password=Password01 quay_image=registry.redhat.io/quay/quay-rhel8:v3.8.10 quay_version=v3.8.10 redis_image=registry.redhat.io/rhel8/redis-6:1-92.1669834635 postgres_image=registry.redhat.io/rhel8/postgresql-10:1-203.1669834630 pause_image=registry.access.redhat.com/ubi8/pause:8.7-6 quay_hostname=registry.ocp.anapartner.dev:8443 local_install=true quay_root=/media/mirror-registry quay_storage=quay-storage pg_storage=pg-storage" install_mirror_appliance.ym```

