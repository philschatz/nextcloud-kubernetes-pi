#!/bin/bash
# set -e

export KUBECONFIG=`pwd`/kubeconfig

function wait_for_pods {
    # This is empty if all the pods started:
    remaining_text='run_at_least_once'
    while [[ $remaining_text != '' ]]; do
        remaining_text=$(kubectl get pods --all-namespaces | grep -v Completed | grep ' 0/')
        if [[ $remaining_text != '' ]]; then
            echo ""
            echo "Waiting on pods to finish. some take 4-8min. (Ctrl+C to exit):"
            echo "$remaining_text"
            sleep 10
        fi
    done
}

function apply {
    echo "Starting: $1"
    kubectl apply -f $1
    sleep 1
    wait_for_pods
    echo "Started: $1"
    echo ""
}


apply ./deployments/kubernetes-dashboard.yaml
apply ./deployments/kubernetes-dashboard-extras.yaml
apply ./deployments/nextcloud-namespace.yaml
apply ./deployments/nextcloud-shared-pvc.yaml
apply ./deployments/nextcloud-db.yaml
apply ./deployments/nextcloud-server.yaml
apply ./deployments/nextcloud-ingress.yaml
apply ./deployments/homepage-ingress.yaml
apply ./deployments/photoprism-shared-pvc.yaml
apply ./deployments/photoprism-server.yaml
