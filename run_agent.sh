#!/bin/bash
set -e

if [ ! -d "/var/run/secrets/kubernetes.io/serviceaccount" ]; then
  echo "WARNING: No kubernetes servie account detected!"
  echo " - gcloud commands will not work!"
  echo " - kubectl commands will not work!"
else
  if [ "$GCP_PROJECT_NAME" = "" ]; then
    echo You must specify \$GCP_PROJECT_NAME!
    exit 1
  fi

  if [ "$CLUSTER_NAME" = "" ]; then
    echo No target cluster name specified, will look up current cluster from kube details.
    KUBE_MASTER_IP=$(kubectl cluster-info | head -n 1 | tr '\/\/' ' ' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | awk '{print $7}')
    CLUSTER_NAME=$(gcloud container clusters list | grep $KUBE_MASTER_IP | awk '{print $1}')
    echo Cluster name detected as $CLUSTER_NAME
  fi

  echo Getting credentials for "$CLUSTER_NAME"
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone europe-west1-c --project "$GCP_PROJECT_NAME"
  docker login -u oauth2accesstoken -p "$(gcloud auth print-access-token)" https://eu.gcr.io
  cp -R /root/.docker /var/go/.docker
  cp -R /root/.config /var/go/.config
  cp -R /root/.kube /var/go/.kube
fi

if [ ! -f "/etc/goagent-ssh/ssh-privatekey" ]; then
  echo WARNING: No SSH private key detected at /etc/goagent-ssh/ssh-privatekey
  echo " - Pushing and pulling from private repositories will not work!"
else
  echo Copying public and private keys
  mkdir -p /var/go/.ssh
  cp /etc/goagent-ssh/ssh-privatekey /var/go/.ssh/id_rsa
  cp /etc/goagent-ssh/ssh-publickey /var/go/.ssh/id_rsa.pub
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /var/go/.ssh/config
  chmod 0700 /var/go/.ssh
  chmod 0600 /var/go/.ssh/id_rsa
  chmod 0600 /var/go/.ssh/config
  chmod 0644 /var/go/.ssh/id_rsa.pub
fi

if [ -d "/etc/goagent-gpg" ]; then
  echo "WARNING: No GPG key found in /etc/goagent-gpg"
  echo " - git-crypt will not work!"
else
  GPG="/etc/goagent-gpg/$(ls /etc/goagent-gpg/ | head -n 1)"
  export GPG=$GPG
  if [ -f $GPG ]; then
    echo Importing GPG key
    su -c 'gpg --import $GPG' go
  fi
fi

echo Doing git configuration
git config --global user.email "gocd-agent@noreply.com"
git config --global user.name "GoCD Agent"

echo Making docker socket accessible to go user
chmod 0777 /var/run/docker.sock

echo Fixing file permissions
chown -R go:go /var/go

/sbin/my_init
