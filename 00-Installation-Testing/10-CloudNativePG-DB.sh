#!/usr/bin/env bash
# ================================================================================
#  [10] CloudNativePG Database Operator
#  Enterprise HA PostgreSQL Operator & CRD Controller
#
#  Usage: ./10-CloudNativePG-DB.sh {-install|-test|-restart|-uninstall}
# ================================================================================
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
  kubectl apply -f "$HOME/10-CloudNativePG-DB/1-CloudNativePG-Namespace.yaml" || true
  echo "Installing CloudNativePG operator..."
  if [ -f "$HOME/10-CloudNativePG-DB/2-CloudNativePG-Operator.yaml" ]; then
    kubectl apply --server-side -f "$HOME/10-CloudNativePG-DB/2-CloudNativePG-Operator.yaml" || true
  else
    kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.25.0.yaml || true
  fi
  echo "Waiting for CloudNativePG operator pod to be ready..."
  kubectl wait --namespace cnpg-system --for=condition=ready pod --selector=app.kubernetes.io/name=cloudnative-pg --timeout=90s 2>/dev/null || true
  echo "=== [10 Installation Finished Successfully] ==="
}

do_test() {
  CNPG_READY=$(kubectl get pods -n cnpg-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$CNPG_READY" -gt 0 ]; then
    echo "[OK] CloudNativePG Operator is Running ($CNPG_READY pods)"
  else
    fail_exit "[FAIL] CloudNativePG Operator pods are not Running"
  fi
  if kubectl get crd clusters.postgresql.cnpg.io >/dev/null 2>&1; then
    echo "[OK] CloudNativePG CRD clusters.postgresql.cnpg.io is registered"
  else
    fail_exit "[FAIL] CloudNativePG CRD clusters.postgresql.cnpg.io not found"
  fi
  echo "=== [10 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl rollout restart deploy -n cnpg-system 2>/dev/null || true
  echo "=== [10 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  if [ -f "$HOME/10-CloudNativePG-DB/2-CloudNativePG-Operator.yaml" ]; then
    kubectl delete -f "$HOME/10-CloudNativePG-DB/2-CloudNativePG-Operator.yaml" --ignore-not-found 2>/dev/null || true
  fi
  kubectl delete ns cnpg-system --ignore-not-found 2>/dev/null || true
  echo "=== [10 Uninstallation Completed Successfully] ==="
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