#!/usr/bin/env bash
# ================================================================================
#  [13] Falco Runtime Security
#  Modern eBPF Kernel Threat Detection & Falcosidekick UI Ingress
#
#  Usage: ./13-Falco-Security.sh {-install|-test|-restart|-uninstall}
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
  kubectl apply -f "$HOME/13-Falco-Security/1-Falco-Namespace.yaml" || true
  kubectl apply -f "$HOME/13-Falco-Security/My-Falco-ExternalSecret.yaml" || true
  helm upgrade --install falco falcosecurity/falco \
    -n falco --create-namespace \
    -f "$HOME/13-Falco-Security/My-Falco-Config.yaml" || true
  kubectl apply -f "$HOME/13-Falco-Security/2-Falco-Ingress.yaml" || true
  echo "=== [13 Installation Finished Successfully] ==="
}

do_test() {
  FALCO_READY=$(kubectl get pods -n falco --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$FALCO_READY" -gt 0 ]; then
    echo "[OK] Falco is Running ($FALCO_READY pods)"
  else
    fail_exit "[FAIL] Falco pods are not Running"
  fi
  echo "=== [13 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl get externalsecret -n falco --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n falco force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n falco 2>/dev/null || true
  kubectl rollout restart ds -n falco 2>/dev/null || true
  echo "=== [13 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/13-Falco-Security" ] && kubectl delete -f "$HOME/13-Falco-Security" --ignore-not-found 2>/dev/null || true
  helm uninstall falco -n falco 2>/dev/null || true
  kubectl delete ns falco --ignore-not-found 2>/dev/null || true
  echo "=== [13 Uninstallation Completed Successfully] ==="
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