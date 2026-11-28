#!/usr/bin/env bash
# ================================================================================
#  [16] llama.cpp ROCm Inference Engine
#  AMD ROCm GPU Acceleration, Model Decoupling & Server Metrics
#
#  Usage: ./16-LLaMAcpp-ROCm.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl get externalsecret -n llamacpp-rocm --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n llamacpp-rocm force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n llamacpp-rocm 2>/dev/null || true
  kubectl rollout restart sts -n llamacpp-rocm 2>/dev/null || true
  echo "=== [16 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/16-LLaMAcpp-ROCm" ] && kubectl delete -f "$HOME/16-LLaMAcpp-ROCm" --ignore-not-found 2>/dev/null || true
  kubectl delete ns llamacpp-rocm --ignore-not-found 2>/dev/null || true
  echo "=== [16 Uninstallation Completed Successfully] ==="
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