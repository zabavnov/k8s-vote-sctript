# Generate a CA private key
 openssl genrsa -out ca.key 2048

# Create a self signed Certificate, valid for 10yrs with the 'signing' option set
 openssl req -x509 -new -nodes -key ca.key -subj "/CN=Zabavnov" -days 3650 -reqexts v3_req -extensions v3_ca -out ca.crt

kubectl create secret tls ca-key-pair \
   --cert=ca.crt \
   --key=ca.key \
   --namespace=default

kubectl apply -f k8s-specifications
