#!/usr/bin/env bash
# =====================================================================
#  [7] Cloudflare Tunnel
#  Cloudflare Zero Trust Dual-Replica Encrypted Tunnel (*.kung.nyc)
#
#  Usage: ./07-Cloudflare-Tunnel.sh {-install|-test|-restart|-uninstall}
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
  local DIR="$HOME/07-Cloudflare-Tunnel"
  [ ! -d "$DIR" ] && DIR="$HOME/7-Cloudflare-Tunnel"

  kubectl apply -f "$DIR/1-Cloudflare-KV-Namespace.yaml" || \
    kubectl create namespace cloudflare-kv --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$DIR" || true
  echo "=== [7 Installation Finished Successfully] ==="
}

do_test() {
  CF_READY=$(kubectl get pods -n cloudflare-kv -l app=cloudflared-tunnel-pod --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$CF_READY" -gt 0 ]; then
    echo "[OK] Cloudflare Tunnel is Running ($CF_READY pods)"
  else
    fail_exit "[FAIL] Cloudflare Tunnel pods are not Running"
  fi
  echo "=== [7 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl annotate externalsecret my-cloudflare-config -n external-secrets force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  kubectl get externalsecret -n cloudflare-kv --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n cloudflare-kv force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n cloudflare-kv 2>/dev/null || true
  kubectl rollout restart sts -n cloudflare-kv 2>/dev/null || true
  echo "=== [7 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  local DIR="$HOME/07-Cloudflare-Tunnel"
  [ ! -d "$DIR" ] && DIR="$HOME/7-Cloudflare-Tunnel"

  [ -d "$DIR" ] && kubectl delete -f "$DIR" --ignore-not-found 2>/dev/null || true
  kubectl delete ns cloudflare-kv --ignore-not-found 2>/dev/null || true
  echo "=== [7 Uninstallation Completed Successfully] ==="
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
