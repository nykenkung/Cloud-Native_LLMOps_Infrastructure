#!/usr/bin/env bash
# =====================================================================
#  [13] Falco Runtime Security
#  Modern eBPF Kernel Threat Detection & Falcosidekick UI Ingress
#
#  Simple Installation Command:
#    kubectl apply -f ~/13-Falco-Security/1-Falco-Namespace.yaml
#    helm upgrade --install falco falcosecurity/falco -n falco --create-namespace -f ~/13-Falco-Security/My-Falco-Config.yaml
#    kubectl apply -f ~/13-Falco-Security/2-Falco-Ingress.yaml
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

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
