Using instructions here: https://www.gitpod.io/docs/self-hosted/latest/install/install-on-kubernetes

Install [minica](https://github.com/jsha/minica) to generate self-signed certificates (Go needs to be installed):

```sh
./create-certificates.yaml

kubectl create secret generic --namespace gitpod https-certificates --from-file=./https-certificates
```

Start:

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-rabbitmq bitnami/rabbitmq


helm install -f ./values.custom.yaml --atomic --create-namespace --namespace 'gitpod' gitpod gitpod.io/gitpod --version=0.9.0-alpha1
```