#!/usr/bin/env bash
# =====================================================================
#  [6] Tailscale Operator
#  Tailscale Mesh VPN Operator & ProxyGroup Cross-Network Routing
#
#  Simple Installation Command:
#    kubectl apply -f ~/6-Tailscale-Operator/1-Tailscale-Namespace.yaml
#    helm upgrade --install tailscale-operator tailscale/tailscale-operator -n tailscale --create-namespace ...
#    kubectl apply -f ~/6-Tailscale-Operator/2-Tailscale-ProxyGroup.yaml
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
  local DIR="$HOME/06-Tailscale-Operator"
  [ ! -d "$DIR" ] && DIR="$HOME/6-Tailscale-Operator"

  kubectl apply -f "$DIR/1-Tailscale-Namespace.yaml" || true
  kubectl apply -f "$DIR/My-Tailscale-ExternalSecret.yaml" || true
  helm upgrade --install tailscale-operator tailscale/tailscale-operator \
    -n tailscale --create-namespace \
    --set oauth.secret=operator-oauth || true
  kubectl apply -f "$DIR/2-Tailscale-ProxyGroup.yaml" || true
  echo "=== [6 Installation Finished Successfully] ==="
}

do_test() {
  TAILSCALE_READY=$(kubectl get pods -n tailscale --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$TAILSCALE_READY" -gt 0 ]; then
    echo "[OK] Tailscale Operator is Running ($TAILSCALE_READY pods)"
  else
    fail_exit "[FAIL] Tailscale Operator pods are not Running"
  fi
  echo "=== [6 Verification Completed Successfully] ==="
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
