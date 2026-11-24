#!/usr/bin/env bash
# =====================================================================
#  [8] Ingress-Nginx Controller
#  Edge Ingress Controller & Local sslip.io HostNetwork Direct Routing
#
#  Simple Installation Command:
#    kubectl apply -f ~/8-Ingress-Nginx/1-Ingress-Nginx-Namespace.yaml
#    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
#      -n ingress-nginx --create-namespace \
#      --set controller.service.type=ClusterIP \
#      --set controller.hostNetwork=true
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
  local DIR="$HOME/08-Ingress-Nginx"
  [ ! -d "$DIR" ] && DIR="$HOME/8-Ingress-Nginx"

  for ns in argocd falco grafana litellm open-webui qdrant; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - || true
  done
  kubectl apply -f "$DIR/1-Ingress-Nginx-Namespace.yaml" || true
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    -n ingress-nginx --create-namespace \
    --set controller.service.type=ClusterIP \
    --set controller.hostNetwork=true || true
  echo "=== [8 Installation Finished Successfully] ==="
}

do_test() {
  INGRESS_READY=$(kubectl get pods -n ingress-nginx --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$INGRESS_READY" -gt 0 ]; then
    echo "[OK] Ingress-Nginx Controller is Running ($INGRESS_READY pods)"
  else
    fail_exit "[FAIL] Ingress-Nginx pods are not Running"
  fi
  INGRESS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:80" || echo "000")
  if [ "$INGRESS_CODE" = "000" ]; then
    fail_exit "[FAIL] Ingress HTTP 80 Check failed (unreachable)"
  else
    echo "[OK] Ingress HTTP 80 Check: HTTP $INGRESS_CODE"
  fi
  echo "=== [8 Verification Completed Successfully] ==="
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
