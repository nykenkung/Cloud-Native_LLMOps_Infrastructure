#!/usr/bin/env bash
# =====================================================================
#  [14] Grafana & Prometheus LGTM Stack
#  Observability Stack, ServiceMonitors, Dashboards & Ingress
#
#  Simple Installation Command:
#    kubectl apply -f ~/14-Grafana-Prometheus-Stack/1-Grafana-Namespace.yaml
#    helm upgrade --install lgtm-prometheus prometheus-community/kube-prometheus-stack \
#      -n grafana --create-namespace --set grafana.enabled=true \
#      -f ~/14-Grafana-Prometheus-Stack/My-Grafana-Config.yaml
#    kubectl apply -f ~/14-Grafana-Prometheus-Stack/2-Grafana-Ingress.yaml
#    kubectl apply -f ~/14-Grafana-Prometheus-Stack/3-Grafana-LLaMAcpp-ROCm.yaml
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
  kubectl apply -f "$HOME/14-Grafana-Prometheus-Stack/1-Grafana-Namespace.yaml" || true
  kubectl apply -f "$HOME/14-Grafana-Prometheus-Stack/My-Grafana-ExternalSecret.yaml" || true
  helm upgrade --install lgtm-prometheus prometheus-community/kube-prometheus-stack \
    -n grafana --create-namespace \
    --set grafana.enabled=true \
    -f "$HOME/14-Grafana-Prometheus-Stack/My-Grafana-Config.yaml" || true
  kubectl apply -f "$HOME/14-Grafana-Prometheus-Stack/2-Grafana-Ingress.yaml" || true
  kubectl apply -f "$HOME/14-Grafana-Prometheus-Stack/3-Grafana-LLaMAcpp-ROCm.yaml" || true
  echo "=== [14 Installation Finished Successfully] ==="
}

do_test() {
  GRAFANA_PODS=$(kubectl get pods -n grafana --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$GRAFANA_PODS" -gt 0 ]; then
    echo "[OK] Grafana & Prometheus Running Pods: $GRAFANA_PODS"
  else
    fail_exit "[FAIL] Grafana & Prometheus pods are not Running"
  fi
  echo "=== [14 Verification Completed Successfully] ==="
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
