#!/usr/bin/env bash
# =====================================================================
#  [5] External Secrets Operator (ESO)
#  Kubernetes External Secrets for Zero-Trust Credential Sync
#
#  Simple Installation Command:
#    kubectl apply -f ~/5-External-Secrets-Operator/1-External-Secrets-Namespace.yaml
#    helm upgrade --install external-secrets external-secrets/external-secrets \
#      -n external-secrets --create-namespace --set installCRDs=true
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

do_install() {
  kubectl apply -f "$HOME/5-External-Secrets-Operator/1-External-Secrets-Namespace.yaml" || true
  helm upgrade --install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace \
    --set installCRDs=true || true
  echo "=== [5 Installation Finished Successfully] ==="
}

do_test() {
  ESO_READY=$(kubectl get pods -n external-secrets --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$ESO_READY" -gt 0 ]; then
    echo "[OK] External Secrets Operator is Running ($ESO_READY pods)"
  else
    fail_exit "[FAIL] External Secrets Operator pods are not Running"
  fi
  echo "=== [5 Verification Completed Successfully] ==="
}

case "$1" in
  -install|--install|install)
    do_install
    ;;
  -test|--test|test)
    do_test
    ;;
  *)
    echo "Usage: $0 {-install|-test}"
    exit 1
    ;;
esac
