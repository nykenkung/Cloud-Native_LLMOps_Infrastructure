#!/usr/bin/env bash
# ================================================================================
#  [14] Grafana & Prometheus LGTM Stack
#  Observability Stack, ServiceMonitors, Dashboards & Ingress
#
#  Usage: ./14-Grafana-Prometheus-Stack.sh {-install|-test|-restart|-uninstall}
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

do_restart() {
  do_install
  kubectl get externalsecret -n grafana --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n grafana force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n grafana 2>/dev/null || true
  kubectl rollout restart sts -n grafana 2>/dev/null || true
  kubectl rollout restart ds -n grafana 2>/dev/null || true
  echo "=== [14 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/14-Grafana-Prometheus-Stack" ] && kubectl delete -f "$HOME/14-Grafana-Prometheus-Stack" --ignore-not-found 2>/dev/null || true
  helm uninstall lgtm-prometheus -n grafana 2>/dev/null || true
  kubectl delete ns grafana --ignore-not-found 2>/dev/null || true
  echo "=== [14 Uninstallation Completed Successfully] ==="
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