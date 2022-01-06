#!/bin/bash
set -e

export KUBECONFIG=`pwd`/kubeconfig

kubectl delete -f ./deployments/nextcloud-server.yaml
kubectl delete -f ./deployments/nextcloud-db.yaml
kubectl delete -f ./deployments/photoprism-server.yaml

read -p "Would you like to delete ALL of the persistent state? (users, calendars, uploaded images) <y/N> " prompt
if [[ $prompt =~ [yY](es)* ]]
then
    kubectl delete -f ./deployments/nextcloud-shared-pvc.yaml
    kubectl delete -f ./deployments/photoprism-shared-pvc.yaml
fi

kubectl delete -f ./deployments/homepage-ingress.yaml
kubectl delete -f ./deployments/nextcloud-ingress.yaml
kubectl delete -f ./deployments/nextcloud-namespace.yaml

read -p "Would you like to delete the kubernetes-dashboard <y/N> " prompt
if [[ $prompt =~ [yY](es)* ]]
then
    kubectl delete -f ./deployments/kubernetes-dashboard.yaml
    kubectl delete -f ./deployments/kubernetes-dashboard-extras.yaml
fi