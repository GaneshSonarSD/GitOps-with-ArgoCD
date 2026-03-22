#!/bin/bash

set -e

echo "Creating network"
docker network create k3s-net || true

echo "Starting K3s master node"
docker run -d --name k3s-master \
  --privileged \
  --network k3s-net \
  -p 6443:6443 \
  rancher/k3s:latest server \
  --tls-san k3s-master \
  --tls-san localhost

sleep 15

echo "Getting node token"
TOKEN=$(docker exec k3s-master cat /var/lib/rancher/k3s/server/node-token)

echo "Starting worker node 1"
docker run -d --name k3s-worker1 \
  --privileged \
  --network k3s-net \
  rancher/k3s:latest agent \
  --server https://k3s-master:6443 \
  --token $TOKEN

echo "Starting worker node 2"
docker run -d --name k3s-worker2 \
  --privileged \
  --network k3s-net \
  rancher/k3s:latest agent \
  --server https://k3s-master:6443 \
  --token $TOKEN

sleep 20

echo "Exporting kubeconfig..."
docker exec k3s-master cat /etc/rancher/k3s/k3s.yaml > kubeconfig.yaml

sed -i 's/127.0.0.1/localhost/g' kubeconfig.yaml

export KUBECONFIG=$(pwd)/kubeconfig.yaml

echo "Install Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "running CSI S3 Driver"  

#git clone https://github.com/yandex-cloud/k8s-csi-s3.git 
cd k8s-csi-s3/deploy/kubernetes
kubectl apply -f .

echo "Install Argo CD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Install Argo Workflows..."
kubectl create namespace argo || true
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/stable/manifests/install.yaml

echo "Install MetalLB..."
kubectl create namespace metallb-system || true
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.13/config/manifests/metallb-native.yaml


echo "Install Gatekeeper..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

echo "Create dev namespace..."
kubectl create namespace dev || true


