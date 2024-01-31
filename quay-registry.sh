#!/bin/bash
#####################################################################################################
#
#  Goal: Deploy a limited version of RHEL Quay Registry using their binary: mirror-registry
#   - This is a limited version of Quay that was designed to be used with OpenShift deployments
#   - This version is still useful for learning about container registries and the Quay UI
#   - mirror-registry binary uses an Ansible container to deploy these Quay containers
#
#
#  Note1: These containers are deployed with the --rm switch
#    - They should only be stopped/started with systemctl processes
#    systemctl stop quay-app
#
#  Note2:  Address possible deployment/startup error message due to file num locks due to unused podman volumes
#  Ref: https://syshunt.com/how-to-resolve-exceeded-num_locks-in-podman/
#        podman volume rm --all
#
#  Note3: Add TLS certs to avoid deployment issues or use --tls-verify=false to connect with the self-signed certs
#    - To rotate certs, update the files, then issue:  systemctl restart quay-app
#    - Under ${REGISTRY_FOLDER}/quay-config/ssl.cert and ssl.key
#
#  Note4: Optional: Add GitHub .ssh key here for git clone to work.
#
#  Warning:  Default values are initial user credential: init   and  TCP PORT 8443
#
#  Warning:  Quay (at this time) is not supported for NFS for these containers
#            -  PostGres Folder (install requires setfacl)
#            -  Quay Storage Folder
#
#  View new systemd services for the three (3) containers: quay-postgres, quay-redis, quay-app
#    systemctl status quay-*.service -l --no-pager
#
#
# References:
#    https://docs.openshift.com/container-platform/4.14/installing/disconnected_install/installing-mirroring-creating-registry.html
#   - See section on rotating certs #mirror-registry-ssl-cert-replace_installing-mirroring-creating-registry
#
#
#
#  ANA 01/2024
#
#####################################################################################################
# Default username is init
USERNAME=registry
PASSWORD=Password01

TLS_DOMAIN="anapartner.dev"
# Ensure this FQDN resolves to an IP address in your local DNS or online
REGISTRY=registry.ocp.${TLS_DOMAIN}
# Default port is 8443
PORT=443

# Recommendation: Setup LetsEncrypt certs to replace Quay self-signed certs
# - Ensure cert has either FQDN or wildcard SAN certs
CERTFOLDER=/root/labs/letsencrypt
# May use fullchain.pem or combined_chain_with_cert.pem
CERTFILE=${CERTFOLDER}/combined_chain_with_cert.pem
KEYFILE=${CERTFOLDER}/privkey.pem

# Temporary install folder (full path)
TMP=/media/openshift-offline
#sudo rm -rf ${TMP} &>/dev/null
mkdir -p ${TMP}


# Do NOT remove REGISTRY_FOLDER (as this is the physical location where the container files will reside)
REGISTRY_FOLDER=/media/mirror-registry
# Make a folder the first time
mkdir -p ${REGISTRY_FOLDER} &>/dev/null

#####################################################################################################
# Define a timestamp function
timestamp() {
  #date +"%T" # current time
  date '+%Y-%m-%d %H:%M:%S %3N (%A)'
}
#####################################################################################################


echo ""
timestamp
echo "#################################################################################################"
echo "Cert info:"
echo -e "\n$(openssl x509 -noout -text -in $CERTFILE | grep -e 'Subject: ' | xargs )\n"
echo "    Key:      $KEYFILE"
echo "    Cert:     $CERTFILE"
echo ""
EXP_DATE=$(openssl x509 -text -noout -in $CERTFILE | sed -n -e 's/^.*After : //p')
let EXP_DAYS=($(date +%s -d $(date -d "$EXP_DATE" +%F))-$(date --utc +%s))/86400
echo "    Expires:  $EXP_DATE  ($EXP_DAYS days)"
echo ""
echo "#################################################################################################"
echo -e "SANS:  $(openssl x509 -noout -text -in $CERTFILE | grep -i dns | sed -e 's/DNS/\n    DNS/g')\n"


echo ""
echo ""
timestamp
echo "#################################################################################################"
echo "Change working folder to ${TMP} for install process"
cd ${TMP}
pwd
echo ""
echo ""


FILE=mirror-registry.tar.gz
URL=https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/latest/${FILE}
timestamp
echo "#################################################################################################"
echo "########## Download mirror-registry install package if newer         ############################"
echo "#################################################################################################"
echo "wget -nv -N  ${URL} "
wget -nv -N  ${URL}
timestamp
echo "#################################################################################################"
echo "######### Extract embedded containers (tar) from install package     ############################"
echo "#################################################################################################"
echo "time tar --overwrite -zxvf ${FILE} "
time tar --overwrite -zxvf ${FILE}
ls -lart ${FILE}
ls -lart ${TMP}/mirror-registry
ls -lart ${TMP}/*.tar
echo "#################################################################################################"
echo "tar -tvf ${TMP}/image-archive.tar "
tar -tvf ${TMP}/image-archive.tar

echo ""
echo ""
timestamp
echo "#################################################################################################"
echo "########## Uninstall Prior mirror-registry deployment                        ####################"
echo "#################################################################################################"
podman ps -a
timestamp
echo "#################################################################################################"
echo "Remove any prior ansible_runner_instance container that may be broken and impact deployment"
echo "  Example: if control C was used prior to break from shell script "
echo ""
echo "podman rm -f ansible_runner_instance "
podman rm -f ansible_runner_instance
timestamp
echo "#################################################################################################"
echo "time sudo ./mirror-registry uninstall -v --quayRoot  ${REGISTRY_FOLDER} --autoApprove true "
time sudo ./mirror-registry uninstall -v --quayRoot  ${REGISTRY_FOLDER} --autoApprove true
echo "#################################################################################################"
timestamp
podman ps -a
sleep 5

echo ""
echo ""
echo ""
timestamp
echo "#################################################################################################"
echo "########## Install mirror-registry with LetsEncrypt certs and verbose mode   ####################"
echo "#################################################################################################"
timestamp
echo "time sudo ./mirror-registry install --initUser ${USERNAME} --initPassword ${PASSWORD} --quayHostname ${REGISTRY}:${PORT} --quayRoot ${REGISTRY_FOLDER}  --sslCert ${CERTFILE} --sslKey ${KEYFILE} -v "
time sudo ./mirror-registry install --initUser ${USERNAME} --initPassword ${PASSWORD} --quayHostname ${REGISTRY}:${PORT} --quayRoot ${REGISTRY_FOLDER}  --sslCert ${CERTFILE} --sslKey ${KEYFILE} -v
timestamp
echo "#################################################################################################"
podman ps -a


echo ""
timestamp
echo "#################################################################################################"
echo "Ensure a single config.json file is updated"
echo "podman login -u ${USERNAME} -p ${PASSWORD} ${REGISTRY}:${PORT} --authfile $HOME/.docker/config.json  --tls-verify=false "
podman login -u ${USERNAME} -p ${PASSWORD} ${REGISTRY}:${PORT} --authfile $HOME/.docker/config.json  --tls-verify=false


echo ""
timestamp
echo "#################################################################################################"
# Important note: service must equal the hostname AND port to return the correct API token and not a credential token
echo "curl -s -u \"${USERNAME}:${PASSWORD}\" -X GET \"https://${REGISTRY}:${PORT}/v2/auth?account=${USERNAME}&client_id=docker&offline_token=true&service=${REGISTRY}:${PORT}\" | jq -r .token"
TOKEN=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "https://${REGISTRY}:${PORT}/v2/auth?account=${USERNAME}&client_id=docker&offline_token=true&service=${REGISTRY}:${PORT}" | jq -r .token)

echo "

TOKEN for local ${REGISTRY}:${PORT} is: ${TOKEN}

curl -sL -H \"Authorization: Bearer ${TOKEN}\"   \"https://${REGISTRY}:${PORT}/v2/_catalog\" | jq -r

"
# Run the below command to view current registry catalog
curl -sL -H "Authorization: Bearer ${TOKEN}"   "https://${REGISTRY}:${PORT}/v2/_catalog" | jq -r

echo "

#################################################################################################
Use a browser to access the registry at :  https://${REGISTRY}:${PORT}
Login with l: ${USERNAME}   p: ${PASSWORD}
#################################################################################################

View systemctl processes created for all three (3) containers - type the below command:

 systemctl cat quay*.service --no-pager


To replace TLS certs, stop/start the primary container:

 systemctl stop quay-app.service
 cp -r -p new_cert.pem ${REGISTRY_FOLDER}/quay-config/ssl.cert
 cp -r -p new_ssl.key  ${REGISTRY_FOLDER}/quay-config/ssl.key
 systemctl start quay-app.service
 systemctl status quay-app.service --no-pager


"
