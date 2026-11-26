#!/usr/bin/env bash
# =====================================================================
#  [6] Tailscale Operator
#  Tailscale Mesh VPN Operator & ProxyGroup Cross-Network Routing
#
#  Usage: ./06-Tailscale-Operator.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl get externalsecret -n tailscale --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n tailscale force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n tailscale 2>/dev/null || true
  kubectl rollout restart sts -n tailscale 2>/dev/null || true
  echo "=== [6 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  local DIR="$HOME/06-Tailscale-Operator"
  [ ! -d "$DIR" ] && DIR="$HOME/6-Tailscale-Operator"

  [ -d "$DIR" ] && kubectl delete -f "$DIR" --ignore-not-found 2>/dev/null || true
  helm uninstall tailscale-operator -n tailscale 2>/dev/null || true
  kubectl delete ns tailscale --ignore-not-found 2>/dev/null || true
  echo "=== [6 Uninstallation Completed Successfully] ==="
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
