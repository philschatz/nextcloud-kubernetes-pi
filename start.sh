#!/bin/sh
set -e

kubectl apply -f ./deployments/cluster-ingress.yaml
kubectl apply -f ./deployments/nextcloud-shared-pvc.yaml
kubectl apply -f ./deployments/nextcloud-db.yaml
kubectl apply -f ./deployments/nextcloud-server.yaml