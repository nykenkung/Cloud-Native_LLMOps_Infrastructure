#!/usr/bin/env bash
# =====================================================================
#  [9] JuiceFS CSI Driver
#  Distributed POSIX Storage Driver & Cloudflare R2 StorageClass
#
#  Simple Installation Command:
#    sudo mount --make-shared / 2>/dev/null || true
#    helm upgrade --install juicefs-csi-driver juicefs/juicefs-csi-driver -n kube-system
#    kubectl apply -f ~/9-JuiceFS-CSI-Driver
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
  local DIR="$HOME/09-JuiceFS-CSI-Driver"
  [ ! -d "$DIR" ] && DIR="$HOME/9-JuiceFS-CSI-Driver"

  sudo mount --make-shared / 2>/dev/null || true
  helm upgrade --install juicefs-csi-driver juicefs/juicefs-csi-driver -n kube-system || true
  kubectl apply -f "$DIR" || true
  echo "=== [9 Installation Finished Successfully] ==="
}

do_test() {
  JUICEFS_READY=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=juicefs-csi-driver --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$JUICEFS_READY" -gt 0 ]; then
    echo "[OK] JuiceFS CSI Driver is Running ($JUICEFS_READY pods)"
  else
    fail_exit "[FAIL] JuiceFS pods not found or not Running"
  fi
  if kubectl get sc cloudflare-juicefs-sc >/dev/null 2>&1; then
    echo "[OK] StorageClass cloudflare-juicefs-sc is available"
  else
    fail_exit "[FAIL] StorageClass cloudflare-juicefs-sc not found"
  fi
  echo "=== [9 Verification Completed Successfully] ==="
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
