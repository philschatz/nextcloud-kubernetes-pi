#!/bin/sh
set -e

export KUBECONFIG=`pwd`/kubeconfig

kubectl apply -f ./deployments/kubernetes-dashboard.yaml
kubectl apply -f ./deployments/kubernetes-dashboard-extras.yaml
kubectl apply -f ./deployments/cluster-ingress.yaml
kubectl apply -f ./deployments/nextcloud-shared-pvc.yaml
kubectl apply -f ./deployments/nextcloud-db.yaml
kubectl apply -f ./deployments/nextcloud-server.yaml
kubectl apply -f ./deployments/photoprism-shared-pvc.yaml
kubectl apply -f ./deployments/photoprism-server.yaml
