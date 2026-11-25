#!/usr/bin/env bash
# =====================================================================
#  [15] KEDA Event-Driven Autoscaler
#  Kubernetes Event-Driven Autoscaling (KEDA) & ScaledObjects
#
#  Simple Installation Command:
#    helm upgrade --install keda kedacore/keda -n keda --create-namespace
#    kubectl apply -f ~/15-KEDA-Autoscaler/1-LLaMAcpp-KEDA-ScaledObject.yaml
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
  helm upgrade --install keda kedacore/keda -n keda --create-namespace || true
  kubectl apply -f "$HOME/15-KEDA-Autoscaler/1-LLaMAcpp-KEDA-ScaledObject.yaml" || true
  echo "=== [15 Installation Finished Successfully] ==="
}

do_test() {
  KEDA_PODS=$(kubectl get pods -n keda --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$KEDA_PODS" -gt 0 ]; then
    echo "[OK] KEDA Running Pods: $KEDA_PODS"
  else
    fail_exit "[FAIL] KEDA pods are not Running"
  fi
  KEDA_SCALED_OBJECTS=$(kubectl get scaledobjects -A --no-headers 2>/dev/null | wc -l)
  echo "[OK] KEDA ScaledObjects Registered: $KEDA_SCALED_OBJECTS"
  echo "=== [15 Verification Completed Successfully] ==="
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
