#!/bin/sh
set -e

kubectl delete -f ./deployments/nextcloud-server.yaml
kubectl delete -f ./deployments/nextcloud-db.yaml
kubectl delete -f ./deployments/nextcloud-shared-pvc.yaml
kubectl delete -f ./deployments/cluster-ingress.yaml