# Install minica: go get github.com/jsha/minica
minica --domains 'gitpod.lan,*.gitpod.lan,*.ws.gitpod.lan'

[[ -d ./https-certificates/ ]] || mkdir -p ./https-certificates/

# Cert explanations: https://community.letsencrypt.org/t/generating-cert-pem-chain-pem-and-fullchain-pem-from-order-certificate/78376/5
# https://www.cloudsavvyit.com/1727/what-is-a-pem-file-and-how-do-you-use-it/
cp ./gitpod.lan/cert.pem ./https-certificates/cert.pem
cp ./gitpod.lan/key.pem ./https-certificates/privkey.pem
cat ./gitpod.lan/cert.pem > ./https-certificates/fullchain.pem 
cat ./minica.pem >> ./https-certificates/fullchain.pem
cp ./minica.pem ./https-certificates/chain.pem