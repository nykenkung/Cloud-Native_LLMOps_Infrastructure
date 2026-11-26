#!/usr/bin/env bash
# =====================================================================
#  [11] Qdrant Vector Database
#  High-Performance Vector Similarity Search Engine & Ingress
#
#  Usage: ./11-Qdrant-Vector-DB.sh {-install|-test|-restart|-uninstall}
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
  kubectl apply -f "$HOME/11-Qdrant-Vector-DB/1-Qdrant-Namespace.yaml"
  kubectl apply -f "$HOME/11-Qdrant-Vector-DB/My-Qdrant-ExternalSecret.yaml"
  helm upgrade --install qdrant qdrant/qdrant \
    -n qdrant --create-namespace \
    --set apiKey=false,readOnlyApiKey=false \
    --set env[0].name=QDRANT__SERVICE__API_KEY,env[0].valueFrom.secretKeyRef.name=my-qdrant-config,env[0].valueFrom.secretKeyRef.key=MY-QDRANT-KEY \
    --set env[1].name=QDRANT__SERVICE__READ_ONLY_API_KEY,env[1].valueFrom.secretKeyRef.name=my-qdrant-config,env[1].valueFrom.secretKeyRef.key=MY-QDRANT-READ-ONLY-KEY || true
  kubectl apply -f "$HOME/11-Qdrant-Vector-DB/2-Qdrant-Ingress.yaml" || true
  echo "=== [11 Installation Finished Successfully] ==="
}

do_test() {
  QDRANT_PODS=$(kubectl get pods -n qdrant --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [ "$QDRANT_PODS" -gt 0 ]; then
    echo "[OK] Qdrant Running Pods: $QDRANT_PODS"
  else
    fail_exit "[FAIL] Qdrant pods are not Running"
  fi
  QDRANT_IP=$(kubectl get svc -n qdrant qdrant -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
  if [ -z "$QDRANT_IP" ]; then
    QDRANT_IP=$(kubectl get svc -n qdrant -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
  fi
  if [ -z "$QDRANT_IP" ]; then
    fail_exit "[FAIL] Qdrant service IP not found in namespace qdrant"
  fi
  QDRANT_HEALTH=$(curl -s --max-time 5 "http://${QDRANT_IP}:6333/healthz" 2>/dev/null || echo "failed")
  if echo "$QDRANT_HEALTH" | grep -q "passed\|ok\|true"; then
    echo "[OK] Qdrant /healthz: $QDRANT_HEALTH"
  else
    fail_exit "[FAIL] Qdrant /healthz check failed: $QDRANT_HEALTH"
  fi
  echo "=== [11 Verification Completed Successfully] ==="
}

do_restart() {
  do_install
  kubectl get externalsecret -n qdrant --no-headers 2>/dev/null | awk '{print $1}' | while read -r name; do
    [ -n "$name" ] && kubectl annotate externalsecret "$name" -n qdrant force-sync="$(date +%s)" --overwrite >/dev/null 2>&1 || true
  done
  kubectl rollout restart deploy -n qdrant 2>/dev/null || true
  kubectl rollout restart sts -n qdrant 2>/dev/null || true
  echo "=== [11 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  [ -d "$HOME/11-Qdrant-Vector-DB" ] && kubectl delete -f "$HOME/11-Qdrant-Vector-DB" --ignore-not-found 2>/dev/null || true
  helm uninstall qdrant -n qdrant 2>/dev/null || true
  kubectl delete ns qdrant --ignore-not-found 2>/dev/null || true
  echo "=== [11 Uninstallation Completed Successfully] ==="
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
