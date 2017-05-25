#!/bin/bash

# This script installs the kubernetes packages

set -o errexit -o xtrace

zypper addrepo --gpgcheck --refresh --priority 120 --check \
    obs://Virtualization:containers Virtualization:containers
zypper --gpg-auto-import-keys refresh
zypper repos --uri # for troubleshooting
zypper install --no-confirm --from Virtualization:containers \
    docker \
    etcd \
    kubernetes-client \
    kubernetes-kubelet \
    kubernetes-master \
    kubernetes-node \
    kubernetes-addons-kubedns \
    kubernetes-node-cni \
    kubernetes-node-image-pause \
    jq # not kubernetes, but really useful

systemctl enable etcd.service
systemctl enable kube-apiserver.service
systemctl enable kube-controller-manager.service
systemctl enable kube-proxy.service
systemctl enable kube-scheduler.service
# these are *not* enabled, so we can create the disk they need in Vagrantfile
systemctl disable docker.service
systemctl disable kubelet.service

# Fake the service account key
ln -s /var/run/kubernetes/apiserver.key /var/lib/kubernetes/serviceaccount.key

# Temporarily start docker for go; we'll clean up after
systemctl start docker.service

# Create certificates
mkdir /run/certstrap
docker run --rm -v /run/certstrap:/out:rw golang:1.7 /usr/bin/env GOBIN=/out go get github.com/square/certstrap
export PATH=$PATH:/run/certstrap
certstrap --depot-path "/run/certstrap" init --common-name "CA.kube.vagrant" --passphrase "" --years 10
certstrap --depot-path "/run/certstrap" request-cert --common-name "apiserver" --passphrase "" --ip 127.0.0.1,192.168.88.88,172.17.0.1,10.254.0.1 --domain kubernetes.default.svc,kubernetes.default,kubernetes,localhost
certstrap --depot-path "/run/certstrap" sign "apiserver" --CA "CA.kube.vagrant" --passphrase ""
certstrap --depot-path "/run/certstrap" request-cert --common-name "kubelet" --passphrase "" --ip 127.0.0.1
certstrap --depot-path "/run/certstrap" sign "kubelet" --CA "CA.kube.vagrant" --passphrase ""
mkdir /etc/kubernetes/{certs,ca}
chmod 0400 /run/certstrap/{apiserver,kubelet}.key
mv /run/certstrap/{apiserver,kubelet,CA.kube.vagrant}.{crt,key} /etc/kubernetes/certs/
chown kube:kube /etc/kubernetes/certs/apiserver.{crt,key} /etc/kubernetes/ca/
cp /etc/kubernetes/certs/CA.kube.vagrant.crt /etc/pki/trust/anchors/
update-ca-certificates

# Turn on host path volume provisioning
perl -p -i -e 's@^(KUBE_CONTROLLER_MANAGER_ARGS=)"(.*)"@\1"\2 --enable-hostpath-provisioner --root-ca-file=/etc/kubernetes/ca/ca.pem"@' /etc/kubernetes/controller-manager

# Fix the DNS
perl -p -i -e 's@^(KUBELET_ARGS=)"(.*)"@\1"\2 --cluster-dns=10.254.0.254 --cluster-domain=cluster.local"@' /etc/kubernetes/kubelet
perl -p -i -e '
        s@clusterIP:.*@clusterIP: 10.254.0.254@ ;
        s@170Mi@256Mi@ ;
        s@70Mi@128Mi@ ;
    ' /etc/kubernetes/addons/kubedns.yml

# Clean up docker
systemctl stop docker.service
set -o xtrace +o errexit
btrfs subvolume list /var/lib/docker | awk '/docker/ { print "/" $NF }' | xargs --no-run-if-empty btrfs subvolume delete -c
rm -rf /var/lib/docker/* # We'll have a mount point for this afterwards
