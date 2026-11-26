#!/usr/bin/env bash
# =====================================================================
#  [91] Check Cluster Deployment & Pod Status
#  Inspects ClusterSecretStore, Deployments, StatefulSets, and Pods
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

echo ">>> [1/3] ClusterSecretStore:"
kubectl get clustersecretstore
echo ""

echo ">>> [2/3] Deployments & StatefulSets (All Namespaces):"
kubectl get deploy,sts -A
echo ""

echo ">>> [3/3] Pods (All Namespaces):"
kubectl get pods -A
