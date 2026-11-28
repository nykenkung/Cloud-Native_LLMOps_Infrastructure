#!/usr/bin/env bash
# ================================================================================
#  [17] LiteLLM API Gateway
#  OpenAI-Compatible Multi-Model Router, CNPG Database & Prometheus Metrics
#
#  Usage: ./17-LiteLLM-Gateway.sh {-install|-test|-restart|-uninstall}
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
  kubectl apply -f "$HOME/17-LiteLLM-Gateway/1-LiteLLM-Namespace.yaml"
  kubectl apply -f "$HOME/17-LiteLLM-Gateway/My-LiteLLM-ExternalSecret.yaml"
  for f in "$HOME/17-LiteLLM-Gateway"/[2-9]-*.yaml; do
    [ -f "$f" ] && kubectl apply -f "$f"
  done
  echo "=== [17 Installation Finished Successfully] ==="
}

do_test() {
  LITELLM_PODS=$(kubectl get pods -n litellm --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$LITELLM_PODS" -gt 0 ]; then
    echo "[OK] LiteLLM Running Pods: $LITELLM_PODS"
  else
    fail_exit "[FAIL] LiteLLM pods are not Running"
  fi
  LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
  if [ -z "$LITELLM_IP" ]; then
    fail_exit "[FAIL] LiteLLM service IP not found in namespace litellm"
  fi
  LITELLM_HEALTH=$(curl -s --max-time 5 "http://${LITELLM_IP}:4000/health/liveliness" 2>/dev/null || echo "failed")
  if echo "$LITELLM_HEALTH" | grep -q "healthy\|ok\|alive"; then
    echo "[OK] LiteLLM /health/liveliness: $LITELLM_HEALTH"
  else
    fail_exit "[FAIL] LiteLLM /health/liveliness check failed: $LITELLM_HEALTH"
  fi
  INGRESS_API=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: api.192.168.1.3.sslip.io" --max-time 5 "http://127.0.0.1:80/health/liveliness" || echo "000")
  if [ "$INGRESS_API" = "000" ]; then
    fail_exit "[FAIL] Ingress HTTP Route (api.192.168.1.3.sslip.io) unreachable"
  else
    echo "[OK] Ingress HTTP Route (api.192.168.1.3.sslip.io): HTTP $INGRESS_API"
  fi
  echo "=== [17 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl get externalsecret -n litellm --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n litellm force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n litellm 2>/dev/null || true
  kubectl rollout restart sts -n litellm 2>/dev/null || true
  echo "=== [17 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/17-LiteLLM-Gateway" ] && kubectl delete -f "$HOME/17-LiteLLM-Gateway" --ignore-not-found 2>/dev/null || true
  kubectl delete ns litellm --ignore-not-found 2>/dev/null || true
  echo "=== [17 Uninstallation Completed Successfully] ==="
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