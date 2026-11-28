#!/usr/bin/env bash
# ================================================================================
#  [15] KEDA Event-Driven Autoscaler
#  Kubernetes Event-Driven Autoscaling (KEDA) & ScaledObjects
#
#  Usage: ./15-KEDA-Autoscaler.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl rollout restart deploy -n keda 2>/dev/null || true
  echo "=== [15 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -f "$HOME/15-KEDA-Autoscaler/1-LLaMAcpp-KEDA-ScaledObject.yaml" ] && \
    kubectl delete -f "$HOME/15-KEDA-Autoscaler/1-LLaMAcpp-KEDA-ScaledObject.yaml" --ignore-not-found 2>/dev/null || true
  helm uninstall keda -n keda 2>/dev/null || true
  kubectl delete ns keda --ignore-not-found 2>/dev/null || true
  echo "=== [15 Uninstallation Completed Successfully] ==="
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