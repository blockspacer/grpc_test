#!/usr/bin/env bash

set -eo pipefail

# Install Tiller (the Helm server-side component) into the Kubernetes cluster:
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --wait --service-account tiller
helm repo update

# Check if the tiller was installed properly:
kubectl get pods -l app=helm --all-namespaces