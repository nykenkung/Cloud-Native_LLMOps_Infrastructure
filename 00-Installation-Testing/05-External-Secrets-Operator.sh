#!/usr/bin/env bash
# =====================================================================
#  [5] External Secrets Operator (ESO)
#  Kubernetes External Secrets for Zero-Trust Credential Sync (GCP WIF)
#
#  Usage: ./05-External-Secrets-Operator.sh {-install|-test|-restart|-uninstall}
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "$1"; exit 1; }

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
  if [ -f "$DIR/My-ESO-Config.yaml" ]; then
    helm upgrade --install external-secrets external-secrets/external-secrets \
      -n external-secrets --create-namespace \
      --version 2.15.0 \
      -f "$DIR/My-ESO-Config.yaml" || true
  elif ! helm status external-secrets -n external-secrets >/dev/null 2>&1; then
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
      fail_exit "[FAIL] ClusterSecretStore 'gcp-secret-store' status is: $CSS_STATUS"
    fi
  else
    fail_exit "[FAIL] ClusterSecretStore 'gcp-secret-store' not found."
  fi

  echo ">>> Checking Synced ExternalSecrets..."
  kubectl get externalsecrets -A 2>/dev/null || true

  echo "=== [5 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  echo ">>> Forcing ExternalSecrets re-sync across cluster..."
  kubectl get externalsecret -A --no-headers 2>/dev/null | awk '{print $1, $2}' | while read -r ns name; do
    [ -n "$ns" ] && [ -n "$name" ] && \
      kubectl annotate externalsecret "$name" -n "$ns" force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  echo ">>> Rolling out external-secrets deployments..."
  kubectl rollout restart deploy -n external-secrets 2>/dev/null || true
  echo "=== [5 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  local DIR="$HOME/05-External-Secrets-Operator"
  [ ! -d "$DIR" ] && DIR="$HOME/5-External-Secrets-Operator"

  [ -f "$DIR/Google-Cloud-Platform-CSS.yaml" ] && kubectl delete -f "$DIR/Google-Cloud-Platform-CSS.yaml" --ignore-not-found 2>/dev/null || true
  helm uninstall external-secrets -n external-secrets 2>/dev/null || true
  kubectl delete ns external-secrets --ignore-not-found 2>/dev/null || true
  echo "=== [5 Uninstallation Completed Successfully] ==="
}

case "$1" in
  -install)   do_install ;;
  -test)      do_test ;;
  -restart)   do_restart ;;
  -uninstall) do_uninstall ;;
  *)
    echo "Usage: $0 {-install|-test|-restart|-uninstall}"
    exit 1
    ;;
esac
