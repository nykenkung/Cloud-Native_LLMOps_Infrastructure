#!/usr/bin/env bash
# =====================================================================
#  [18] Open-WebUI Frontend
#  Enterprise Chatbot UI, Knowledge Base RAG & CloudNativePG Storage
#
#  Usage: ./18-Open-WebUI.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl get externalsecret -n open-webui --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n open-webui force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n open-webui 2>/dev/null || true
  kubectl rollout restart sts -n open-webui 2>/dev/null || true
  echo "=== [18 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/18-Open-WebUI" ] && kubectl delete -f "$HOME/18-Open-WebUI" --ignore-not-found 2>/dev/null || true
  kubectl delete ns open-webui --ignore-not-found 2>/dev/null || true
  echo "=== [18 Uninstallation Completed Successfully] ==="
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
