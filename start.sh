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
# [[ -f ./tls-mine.crt ]] || {
#    openssl req -nodes -new -x509 \
#         -keyout ./tls-mine.key \
#         -out ./tls-mine.crt \
#         -config ./tls.conf \
#         -days 3650
# }

DO_REST=0
function run_step_if_file_missing() {
    filename=$1
    shift
    command_and_args="$@"
    if [[ $DO_REST == 1 || ! -f $filename ]]; then
        echo "Running command: $command_and_args"
        "$@"
    else
        echo "Skipping step because file exists: $filename"
    fi
}
# Source: https://stackoverflow.com/a/58580467
# Installing the cert using the older method was not possible because the certificate needed a root CA as well
run_step_if_file_missing tls-root-ca.key    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/O=Personal Cloud Root Authority/CN=cloud" -keyout tls-root-ca.key -out tls-root-ca.crt
run_step_if_file_missing tls-mine.key       openssl genrsa -out "tls-mine.key" 2048
run_step_if_file_missing tls-temp.csr       openssl req -new -key tls-mine.key -out tls-temp.csr -config ./tls.conf
run_step_if_file_missing tls-mine.crt       openssl x509 -req -days 3650 -in tls-temp.csr -CA tls-root-ca.crt -CAkey tls-root-ca.key -CAcreateserial -extensions v3_req -extfile ./tls.conf -out tls-mine.crt


# Generate file from template
TLS_CRT=$(base64 --wrap=0 ./tls-mine.crt) # Kubernetes files are base64 encoded
TLS_KEY=$(base64 --wrap=0 ./tls-mine.key)
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
