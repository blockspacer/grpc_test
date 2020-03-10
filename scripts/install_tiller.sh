#!/usr/bin/env bash

set -eo pipefail

# Install Tiller (the Helm server-side component) into the Kubernetes cluster:
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
# Tiller was removed in helm 3, and therefore helm init is no longer necessary. See https://github.com/helm/helm/issues/7052#issuecomment-557554311
(helm init --service-account tiller --wait || true)
helm repo update

# Check if the tiller was installed properly:
kubectl get pods -l app=helm --all-namespaces