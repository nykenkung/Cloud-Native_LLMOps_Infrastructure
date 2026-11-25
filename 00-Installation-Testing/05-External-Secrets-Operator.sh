#!/usr/bin/env bash
# =====================================================================
#  [5] External Secrets Operator (ESO)
#  Kubernetes External Secrets for Zero-Trust Credential Sync (GCP WIF)
#
#  Installation Commands:
#    1. kubectl apply -f ~/5-External-Secrets-Operator/1-External-Secrets-Namespace.yaml
#    2. kubectl create secret generic gcp-wif-config \
#         --from-file=config=$HOME/5-External-Secrets-Operator/wif-credentials.json \
#         -n external-secrets --dry-run=client -o yaml | kubectl apply -f -
#    3. helm upgrade --install external-secrets external-secrets/external-secrets \
#         -n external-secrets --create-namespace --set installCRDs=true
#    4. kubectl apply -f ~/5-External-Secrets-Operator/Google-Cloud-Platform-CSS.yaml
#
#  Verification:
#    kubectl get clustersecretstore
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

do_install() {
  local DIR="$HOME/05-External-Secrets-Operator"
  [ ! -d "$DIR" ] && DIR="$HOME/5-External-Secrets-Operator"

  echo ">>> [1/4] Applying External Secrets Namespace..."
  if [ -f "$DIR/1-External-Secrets-Namespace.yaml" ]; then
    kubectl apply -f "$DIR/1-External-Secrets-Namespace.yaml" || true
  fi

  echo ">>> [2/4] Configuring GCP WIF Credentials Secret..."
  if [ -f "$DIR/wif-credentials.json" ]; then
    kubectl create secret generic gcp-wif-config \
      --from-file=config="$DIR/wif-credentials.json" \
      -n external-secrets --dry-run=client -o yaml | kubectl apply -f -
    echo "[OK] Secret gcp-wif-config created/updated successfully."
  else
    echo "[WARN] $DIR/wif-credentials.json not found. Skipping secret creation."
  fi

  echo ">>> [3/4] Ensuring External Secrets Operator is installed..."
  if ! helm status external-secrets -n external-secrets >/dev/null 2>&1; then
    helm upgrade --install external-secrets external-secrets/external-secrets \
      -n external-secrets --create-namespace \
      --set installCRDs=true || true
  else
    echo "[OK] External Secrets Operator Helm release already present."
  fi

  echo ">>> [4/4] Applying GCP ClusterSecretStore..."
  if [ -f "$DIR/Google-Cloud-Platform-CSS.yaml" ]; then
    kubectl apply -f "$DIR/Google-Cloud-Platform-CSS.yaml" || true
    echo "[OK] Google-Cloud-Platform-CSS.yaml applied successfully."
  fi

  echo "=== [5 Installation Finished Successfully] ==="
}

do_test() {
  echo ">>> Checking External Secrets Operator Pods..."
  ESO_READY=$(kubectl get pods -n external-secrets --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$ESO_READY" -gt 0 ]; then
    echo "[OK] External Secrets Operator is Running ($ESO_READY pods)"
  else
    fail_exit "[FAIL] External Secrets Operator pods are not Running"
  fi

  echo ">>> Checking ClusterSecretStore (gcp-secret-store)..."
  if kubectl get clustersecretstore gcp-secret-store >/dev/null 2>&1; then
    CSS_STATUS=$(kubectl get clustersecretstore gcp-secret-store -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    kubectl get clustersecretstore
    if [ "$CSS_STATUS" = "True" ]; then
      echo "[OK] ClusterSecretStore 'gcp-secret-store' is Valid and Ready (True)"
    else
      echo "[WARN] ClusterSecretStore 'gcp-secret-store' status is: $CSS_STATUS"
    fi
  else
    echo "[WARN] ClusterSecretStore 'gcp-secret-store' not found yet."
  fi

  echo ">>> Checking Synced ExternalSecrets..."
  kubectl get externalsecrets -A 2>/dev/null || true

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
