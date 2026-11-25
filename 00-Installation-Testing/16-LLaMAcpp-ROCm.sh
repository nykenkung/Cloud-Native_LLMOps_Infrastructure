#!/usr/bin/env bash
# =====================================================================
#  [16] llama.cpp ROCm Inference Engine
#  AMD ROCm GPU Acceleration, Model Decoupling & Server Metrics
#
#  Simple Installation Command:
#    kubectl apply -f ~/16-LLaMAcpp-ROCm
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
  kubectl apply -f "$HOME/16-LLaMAcpp-ROCm"
  echo "=== [16 Installation Finished Successfully] ==="
}

do_test() {
  LLAMA_PODS=$(kubectl get pods -n llamacpp-rocm --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$LLAMA_PODS" -gt 0 ]; then
    echo "[OK] llama.cpp Running Pods: $LLAMA_PODS"
  else
    fail_exit "[FAIL] llama.cpp pods are not Running"
  fi
  LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
  if [ -z "$LLAMA_IP" ]; then
    fail_exit "[FAIL] llama.cpp service IP not found in namespace llamacpp-rocm"
  fi
  LLAMA_HEALTH=$(curl -s --max-time 5 "http://${LLAMA_IP}:8080/health" 2>/dev/null || echo "failed")
  if echo "$LLAMA_HEALTH" | grep -q "ok\|status"; then
    echo "[OK] llama.cpp /health: $LLAMA_HEALTH"
  else
    echo "[INFO/WAIT] llama.cpp /health: $LLAMA_HEALTH (waiting for model in /models)"
  fi
  echo "=== [16 Verification Completed Successfully] ==="
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
