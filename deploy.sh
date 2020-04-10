# Generate a CA private key
 openssl genrsa -out ca.key 2048


# Create a self signed Certificate, valid for 10yrs with the 'signing' option set
openssl req -x509 -new -nodes -key ca.key -subj "/O=Zabavnov/CN=vote.s48.su" -days 365 -reqexts v3_req -extensions v3_ca -out ca


openssl genrsa -out vote.key 2048


openssl req -new -sha256 -key vote.key -subj "/O=Zabavnov/CN=*.s48.su" -out vote.csr



openssl x509 -req -in vote.csr -CA ca -CAkey ca.key -CAcreateserial -out vote.crt -days 500 -sha256


cat vote.crt \
ca > combined-certificates.crt

kubectl delete secret tls-key-pair-combo

kubectl create secret tls tls-key-pair-combo \
   --cert=combined-certificates.crt \
   --key=vote.key \
   --namespace=default

cat combined-certificates.crt

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm install my-nginx stable/nginx-ingress --set rbac.create=true

kubectl apply -f k8s-specifications
