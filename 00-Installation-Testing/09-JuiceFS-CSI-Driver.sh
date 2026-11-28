#!/usr/bin/env bash
# ================================================================================
#  [9] JuiceFS CSI Driver
#  Distributed POSIX Storage Driver & Cloudflare R2 StorageClass
#
#  Usage: ./09-JuiceFS-CSI-Driver.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl rollout restart sts -n kube-system -l app.kubernetes.io/name=juicefs-csi-driver 2>/dev/null || true
  kubectl rollout restart ds -n kube-system -l app.kubernetes.io/name=juicefs-csi-driver 2>/dev/null || true
  kubectl rollout restart deploy -n kube-system -l app.kubernetes.io/name=juicefs-csi-driver 2>/dev/null || true
  echo "=== [9 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  local DIR="$HOME/09-JuiceFS-CSI-Driver"
  [ ! -d "$DIR" ] && DIR="$HOME/9-JuiceFS-CSI-Driver"

  [ -d "$DIR" ] && kubectl delete -f "$DIR" --ignore-not-found 2>/dev/null || true
  helm uninstall juicefs-csi-driver -n kube-system 2>/dev/null || true
  echo "=== [9 Uninstallation Completed Successfully] ==="
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