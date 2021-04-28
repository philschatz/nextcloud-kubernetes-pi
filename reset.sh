#!/bin/bash
set -e

export KUBECONFIG=`pwd`/kubeconfig

kubectl delete -f ./deployments/nextcloud-server.yaml
kubectl delete -f ./deployments/nextcloud-db.yaml

read -p "Would you like to delete ALL of the persistent state? (users, calendars, uploaded images) <y/N> " prompt
if [[ $prompt =~ [yY](es)* ]]
then
    echo kubectl delete -f ./deployments/nextcloud-shared-pvc.y
fi

kubectl delete -f ./deployments/cluster-ingress.yaml