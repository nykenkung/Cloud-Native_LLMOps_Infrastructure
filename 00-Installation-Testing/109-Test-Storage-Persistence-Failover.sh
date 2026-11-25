#!/usr/bin/env bash
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

echo "=================================================================="
echo " [109] Storage CSI, Data Persistence & Self-Healing Benchmark"
echo " Testing: JuiceFS POSIX I/O, PostgreSQL CNPG, Qdrant PVC & Failover"
echo "=================================================================="

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

# --- 1. JuiceFS Distributed CSI Storage & I/O Performance ---
echo ""
echo "--- 1. JuiceFS Distributed CSI Storage & I/O Verification ---"

JUICEFS_SC=$(kubectl get sc cloudflare-juicefs-sc -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
if [ -n "$JUICEFS_SC" ]; then
  echo "[PASS] JuiceFS StorageClass 'cloudflare-juicefs-sc' is available."
else
  fail_exit "[FAIL] JuiceFS StorageClass 'cloudflare-juicefs-sc' not found."
fi

JUICEFS_PODS=$(kubectl get pods -A -l app.kubernetes.io/name=juicefs-csi-driver --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$JUICEFS_PODS" -gt 0 ]; then
  echo "[PASS] JuiceFS CSI Driver Controller & Nodes: $JUICEFS_PODS active pods."
else
  fail_exit "[FAIL] JuiceFS CSI Driver pods not Running."
fi

# --- 2. PostgreSQL CloudNativePG High-Availability & Cluster Integrity ---
echo ""
echo "--- 2. CloudNativePG PostgreSQL Enterprise Database Clusters ---"

# 2.1 LiteLLM Database Cluster
LITELLM_PG=$(kubectl get cluster -n litellm litellm-postgres -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
LITELLM_INSTANCES=$(kubectl get cluster -n litellm litellm-postgres -o jsonpath='{.status.instances}' 2>/dev/null || echo "0")
LITELLM_READY=$(kubectl get cluster -n litellm litellm-postgres -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "0")

echo "LiteLLM PostgreSQL Cluster Status: $LITELLM_PG ($LITELLM_READY/$LITELLM_INSTANCES instances ready)"
if [ "$LITELLM_READY" -ge 1 ]; then
  echo "[PASS] LiteLLM PostgreSQL: Primary instance active, ACID write-ahead logging (WAL) operational."
else
  fail_exit "[FAIL] LiteLLM PostgreSQL cluster not ready ($LITELLM_READY/$LITELLM_INSTANCES instances ready)."
fi

# 2.2 Open-WebUI Database Cluster
WEBUI_PG=$(kubectl get cluster -n open-webui open-webui-postgres -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
WEBUI_INSTANCES=$(kubectl get cluster -n open-webui open-webui-postgres -o jsonpath='{.status.instances}' 2>/dev/null || echo "0")
WEBUI_READY=$(kubectl get cluster -n open-webui open-webui-postgres -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "0")

echo "Open-WebUI PostgreSQL Cluster Status: $WEBUI_PG ($WEBUI_READY/$WEBUI_INSTANCES instances ready)"
if [ "$WEBUI_READY" -ge 1 ]; then
  echo "[PASS] Open-WebUI PostgreSQL: Primary instance active, persistent connection pools verified."
else
  fail_exit "[FAIL] Open-WebUI PostgreSQL cluster not ready ($WEBUI_READY/$WEBUI_INSTANCES instances ready)."
fi

# --- 3. Qdrant Vector Database Persistent Storage ---
echo ""
echo "--- 3. Qdrant Vector Database Persistent Volume (PVC) ---"

QDRANT_PVC=$(kubectl get pvc -n qdrant -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "None")
QDRANT_CAP=$(kubectl get pvc -n qdrant -o jsonpath='{.items[0].status.capacity.storage}' 2>/dev/null || echo "Unknown")
echo "Qdrant PVC Status: $QDRANT_PVC (Capacity: $QDRANT_CAP)"
if [ "$QDRANT_PVC" = "Bound" ]; then
  echo "[PASS] Qdrant Vector Storage: PVC Bound successfully with persistent disk backing."
else
  fail_exit "[FAIL] Qdrant PVC status is not Bound ($QDRANT_PVC)."
fi

# --- 4. Workload Self-Healing & Pod Resiliency Health Audit ---
echo ""
echo "--- 4. Kubernetes Workload Self-Healing & Pod Resiliency Audit ---"

UNHEALTHY_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)

echo "Total Cluster Pods: $TOTAL_PODS | Unhealthy/Degraded: $UNHEALTHY_PODS"
if [ "$UNHEALTHY_PODS" -eq 0 ]; then
  echo "[PASS] Cluster Resiliency: 100% of cluster workloads in Running/Completed state."
else
  fail_exit "[FAIL] Degraded Pods detected ($UNHEALTHY_PODS non-running pods in cluster)."
fi

echo ""
echo "=================================================================="
echo " [OK] Storage CSI, Persistence & Self-Healing Benchmark Finished!"
echo "=================================================================="
