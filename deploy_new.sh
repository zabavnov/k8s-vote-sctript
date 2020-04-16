#!/bin/bash

export CLOUDSDK_CORE_DISABLE_PROMPTS=1;
export PATH="/usr/lib/google-cloud-sdk/bin:$PATH";

read -p "Enter instance name: " name
# openssl aes-256-cbc -K $encrypted_0c35eebf403c_key -iv $encrypted_0c35eebf403c_iv -in service-account.json.enc -out service-account.json -d
curl https://sdk.cloud.google.com > install.sh
bash install.sh --disable-prompts --install-dir=/usr/lib/
gcloud components update kubectl
gcloud auth activate-service-account --key-file ../service-account.json
gcloud config set project votes-k8s
if [[ "$1" = "--delete" ]]
then
gcloud container clusters delete $name --zone europe-west3-c
fi
gcloud container clusters create $name --zone europe-west3-c
gcloud config set compute/zone europe-west3-c
gcloud container clusters get-credentials vote
openssl genrsa -out ca.key 2048
# Create a self signed Certificate
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
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm install my-nginx stable/nginx-ingress --set rbac.create=true
# Create multiple YAML objects from stdin
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: db
  name: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - image: postgres:9.4
        name: postgres
        env:
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: postgres
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - mountPath: /var/lib/postgresql/data
          name: db-data
          subPath: postgres
      volumes:
      - name: db-data
        persistentVolumeClaim:
          claimName: db-data
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: db
  name: db
spec:
  type: ClusterIP
  ports:
  - name: "db-service"
    port: 5432
    targetPort: 5432
  selector:
    app: db
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-service
  labels:
  annotations:
    kubernetes.io/ingress.class: nginx
    #nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    #nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/add-base-url : "true"
spec:
  tls:
    - hosts:
      - ingress.example.com
      - vote.s48.su
      - result.s48.su
      secretName: tls-key-pair-combo
  rules:
    - host: vote.s48.su
      http:
        paths:
          - path: /
            backend:
              serviceName: vote
              servicePort: 80
    - host: result.s48.su
      http:
         paths:
           - path: /
             backend:
               serviceName: result
               servicePort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: redis
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - image: redis:alpine
        name: redis
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - mountPath: /data
          name: redis-data
        env:
          - name: POSTGRES_USER
            value: postgre
      volumes:
      - name: redis-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: redis
  name: redis
spec:
  type: ClusterIP
  ports:
  - name: "redis-service"
    port: 6379
    targetPort: 6379
  selector:
    app: redis
---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: result
  name: result
spec:
  replicas: 1
  selector:
    matchLabels:
      app: result
  template:
    metadata:
      labels:
        app: result
    spec:
      containers:
      - image: dockersamples/examplevotingapp_result:before
        name: result
        env:
          - name: POSTGRES_USER
            value: postgre
          - name: POSTGRES_PASSWORD
            value: postgres
          - name: PGHOST
            value: db
          - name: POSTGRES_PORT
            value: '5432'
          - name: POSTGRES_DB
            value: postgresdb
        ports:
        - containerPort: 80
          name: result
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: result
  name: result
spec:
  type: ClusterIP
  ports:
  - name: "result-service"
    port: 90
    targetPort: 80
  selector:
    app: result
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: vote
  name: vote
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
    spec:
      containers:
      - image: dockersamples/examplevotingapp_vote:before
        name: vote
        ports:
        - containerPort: 80
          name: vote
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: vote
  name: vote
spec:
  type: ClusterIP
  ports:
  - name: "vote-service"
    port: 80
    targetPort: 80
  selector:
    app: vote
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: worker
  name: worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - image: dockersamples/examplevotingapp_worker
        name: worker
EOF
