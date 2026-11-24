#!/usr/bin/env bash
# =====================================================================
#  [18] Open-WebUI Frontend
#  Enterprise Chatbot UI, Knowledge Base RAG & CloudNativePG Storage
#
#  Simple Installation Command:
#    kubectl apply -f ~/18-Open-WebUI
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
  kubectl apply -f "$HOME/18-Open-WebUI"
  echo "=== [18 Installation Finished Successfully] ==="
}

do_test() {
  WEBUI_PODS=$(kubectl get pods -n open-webui --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$WEBUI_PODS" -gt 0 ]; then
    echo "[OK] Open-WebUI Running Pods: $WEBUI_PODS"
  else
    fail_exit "[FAIL] Open-WebUI pods are not Running"
  fi
  WEBUI_IP=$(kubectl get svc -n open-webui open-webui-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
  if [ -z "$WEBUI_IP" ]; then
    fail_exit "[FAIL] Open-WebUI service IP not found in namespace open-webui"
  fi
  WEBUI_HEALTH=$(curl -s --max-time 5 "http://${WEBUI_IP}:8080/health" 2>/dev/null || echo "failed")
  if echo "$WEBUI_HEALTH" | grep -q "true\|ok"; then
    echo "[OK] Open-WebUI /health: $WEBUI_HEALTH"
  else
    fail_exit "[FAIL] Open-WebUI /health check failed: $WEBUI_HEALTH"
  fi
  INGRESS_WEBUI=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: open-webui.192.168.1.3.sslip.io" --max-time 5 "http://127.0.0.1:80" || echo "000")
  if [ "$INGRESS_WEBUI" = "000" ]; then
    fail_exit "[FAIL] Ingress HTTP Route (open-webui.192.168.1.3.sslip.io) unreachable"
  else
    echo "[OK] Ingress HTTP Route (open-webui.192.168.1.3.sslip.io): HTTP $INGRESS_WEBUI"
  fi
  echo "=== [18 Verification Completed Successfully] ==="
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
