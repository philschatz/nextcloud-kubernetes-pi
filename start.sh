#!/bin/bash
set -e

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
    # wait_for_pods
    echo "Started: $1"
    echo ""
}

# Create TLS certificate
[[ -f ./my-tls.crt ]] || {
   openssl req -nodes -new -x509 \
        -keyout ./my-tls.key \
        -out ./my-tls.crt \
        -config ./my-tls.conf \
        -days 3650
}

# Generate file from template
# TLS_CRT=$(sed -e "s;-----BEGIN CERTIFICATE-----;;g" -e "s;-----END CERTIFICATE-----;;g" ./my-tls.crt | tr -d '\n')
# TLS_KEY=$(sed -e "s-----BEGIN PRIVATE KEY-----;;g" -e "s;-----END PRIVATE KEY-----;;g" ./my-tls.crt | tr -d '\n')
TLS_CRT=$(base64 --wrap=0 ./my-tls.crt) # Kubernetes files are base64 encoded
TLS_KEY=$(base64 --wrap=0 ./my-tls.key)
sed \
    -e "s;%%TLS_CRT%%;$TLS_CRT;g" \
    -e "s;%%TLS_KEY%%;$TLS_KEY;g" \
    ./templates/my-tls-secret.yml > ./deployments/my-tls-secret.yml


apply ./deployments/kubernetes-dashboard.yaml
apply ./deployments/kubernetes-dashboard-extras.yaml
apply ./deployments/nextcloud-namespace.yaml
apply ./deployments/my-tls-secret.yml
apply ./deployments/nextcloud-shared-pvc.yaml
apply ./deployments/nextcloud-db.yaml
apply ./deployments/nextcloud-server.yaml
apply ./deployments/nextcloud-ingress.yaml
apply ./deployments/homepage-ingress.yaml
apply ./deployments/photoprism-shared-pvc.yaml
apply ./deployments/photoprism-server.yaml
