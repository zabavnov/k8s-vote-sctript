# Generate a CA private key
 openssl genrsa -out ca.key 2048


# Create a self signed Certificate, valid for 10yrs with the 'signing' option set
openssl req -x509 -new -nodes -key ca.key -subj "/CN=Zabavnov" -days 365 -reqexts v3_req -extensions v3_ca -out cb.crt

openssl genrsa -out vote.key 2048

openssl req -new -sha256 -key vote.key -subj "/C=US/ST=CA/O=Test/CN=vote.s48.su" -out vote.csr

openssl x509 -req -in vote.csr -CA cb.crt -CAkey ca.key -out vote.crt -days 500 -sha256

cat vote.crt \
cb.crt > combined-certificates.crt

kubectl delete secret tls-key-pair-combo

kubectl create secret tls tls-key-pair-combo \
   --cert=combined-certificates.crt \
   --key=ca.key \
   --namespace=default

cat combined-certificates.crt

kubectl apply -f k8s-specifications
