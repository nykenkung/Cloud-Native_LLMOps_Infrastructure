#!/usr/bin/env bash
set -e

# Robust KUBECONFIG discovery
if [ -z "$KUBECONFIG" ]; then
  if [ -f "$HOME/.kube/config" ] && [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -f "/etc/rancher/k3s/k3s.yaml" ] && [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

echo "=================================================================="
echo " [101] AI Stack End-to-End Pipeline Verification"
echo " Chain: Qdrant -> llama.cpp ROCm -> LiteLLM Gateway -> WebUI"
echo "=================================================================="

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

QDRANT_API_KEY="${QDRANT_API_KEY:-$(kubectl get secret -n qdrant my-qdrant-config -o jsonpath='{.data.MY-QDRANT-KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"
LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"
LLAMA_API_KEY="${LLAMA_API_KEY:-$(kubectl get secret -n llamacpp-rocm llamacpp-api-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"

# 1. Qdrant Vector Database Test
echo ""
echo "--- 1. Testing Qdrant Vector Database ---"
QDRANT_IP=$(kubectl get svc -n qdrant qdrant -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
            kubectl get svc -n qdrant -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -n "$QDRANT_IP" ]; then
  QDRANT_HEALTH=$(curl -s --max-time 5 "http://${QDRANT_IP}:6333/healthz" 2>/dev/null || echo "failed")
  if ! echo "$QDRANT_HEALTH" | grep -qi "ok\|passed\|status"; then
    fail_exit "[FAIL] Qdrant /healthz check failed: $QDRANT_HEALTH"
  fi
  echo "Qdrant ClusterIP: $QDRANT_IP:6333"
  echo "Qdrant /healthz: $QDRANT_HEALTH"
  
  COLLECTIONS=$(curl -s --max-time 5 -H "api-key: ${QDRANT_API_KEY}" "http://${QDRANT_IP}:6333/collections" 2>/dev/null || echo "failed")
  if echo "$COLLECTIONS" | grep -q "result"; then
    echo "[OK] Qdrant Collections API (authenticated): OK"
  else
    fail_exit "[FAIL] Qdrant Collections API: $COLLECTIONS"
  fi
else
  fail_exit "[FAIL] Qdrant service IP not found"
fi

# 2. llama.cpp ROCm Inference Engine Test
echo ""
echo "--- 2. Testing llama.cpp ROCm Inference Engine ---"
LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
          kubectl get svc -n llamacpp-rocm -l app.kubernetes.io/name=llamacpp-rocm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -n "$LLAMA_IP" ]; then
  echo "llama.cpp ClusterIP: $LLAMA_IP:8080"
  LLAMA_HEALTH=$(curl -s --max-time 5 "http://${LLAMA_IP}:8080/health" 2>/dev/null || echo "failed")
  if echo "$LLAMA_HEALTH" | grep -qi "ok\|status"; then
    echo "[OK] llama.cpp /health: $LLAMA_HEALTH"
    TARGET_M=$(curl -s --max-time 5 -H "Authorization: Bearer ${LLAMA_API_KEY}" "http://${LLAMA_IP}:8080/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | grep -i "0.5b\|fast\|mini" | head -n 1 | sed 's/"id":"//;s/"//')
    [ -z "$TARGET_M" ] && TARGET_M=$(curl -s --max-time 5 -H "Authorization: Bearer ${LLAMA_API_KEY}" "http://${LLAMA_IP}:8080/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"//;s/"//')
    [ -z "$TARGET_M" ] && TARGET_M="qwen2.5-0.5b-instruct"
    LLAMA_TEST=$(curl -s --max-time 30 -H "Authorization: Bearer ${LLAMA_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"${TARGET_M}\", \"prompt\": \"Hello\", \"n_predict\": 5}" \
      "http://${LLAMA_IP}:8080/completion" 2>/dev/null || echo "error")
    if echo "$LLAMA_TEST" | grep -qi "content\|text"; then
      echo "[OK] llama.cpp Test Generation ($TARGET_M): OK"
    else
      echo "llama.cpp Test Generation: $LLAMA_TEST"
    fi
  else
    echo "[INFO/WAIT] llama.cpp /health: $LLAMA_HEALTH (waiting for model file in /models)"
  fi
else
  fail_exit "[FAIL] llama.cpp service IP not found"
fi

# 3. LiteLLM API Gateway Test
echo ""
echo "--- 3. Testing LiteLLM API Gateway & Database ---"
LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
             kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -n "$LITELLM_IP" ]; then
  echo "LiteLLM ClusterIP: $LITELLM_IP:4000"
  LITELLM_HEALTH=$(curl -s --max-time 5 "http://${LITELLM_IP}:4000/health/liveliness" 2>/dev/null || echo "failed")
  if ! echo "$LITELLM_HEALTH" | grep -qi "ok\|alive\|healthy\|status"; then
    fail_exit "[FAIL] LiteLLM /health/liveliness check failed: $LITELLM_HEALTH"
  fi
  echo "LiteLLM /health/liveliness: $LITELLM_HEALTH"
  
  MODELS_LIST=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "http://${LITELLM_IP}:4000/v1/models" 2>/dev/null || echo "failed")
  if echo "$MODELS_LIST" | grep -q "data"; then
    echo "[OK] LiteLLM /v1/models (authenticated with Master Key): OK"
  else
    fail_exit "[FAIL] LiteLLM /v1/models: $MODELS_LIST"
  fi
else
  fail_exit "[FAIL] LiteLLM service IP not found"
fi

# 4. Open-WebUI Frontend & Ingress Test
echo ""
echo "--- 4. Testing Open-WebUI Frontend & Ingress ---"
WEBUI_IP=$(kubectl get svc -n open-webui open-webui-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
          kubectl get svc -n open-webui -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -n "$WEBUI_IP" ]; then
  echo "Open-WebUI ClusterIP: $WEBUI_IP:8080"
  WEBUI_HEALTH=$(curl -s --max-time 5 "http://${WEBUI_IP}:8080/health" 2>/dev/null || echo "failed")
  if ! echo "$WEBUI_HEALTH" | grep -qi "ok\|healthy\|true\|status"; then
    fail_exit "[FAIL] Open-WebUI /health check failed: $WEBUI_HEALTH"
  fi
  echo "[OK] Open-WebUI /health: $WEBUI_HEALTH"
  
  INGRESS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: open-webui.192.168.1.3.sslip.io" --max-time 5 "http://127.0.0.1:80" || echo "000")
  if [ "$INGRESS_CODE" = "000" ]; then
    fail_exit "[FAIL] Ingress HTTP Route (open-webui.192.168.1.3.sslip.io) unreachable (HTTP 000)"
  fi
  echo "[OK] Ingress HTTP Route (open-webui.192.168.1.3.sslip.io): HTTP $INGRESS_CODE"
else
  fail_exit "[FAIL] Open-WebUI service IP not found"
fi

# 5. Cloudflare Zero Trust Tunnel Test
echo ""
echo "--- 5. Testing Cloudflare Zero Trust Tunnel Pods ---"
CF_PODS=$(kubectl get pods -n cloudflare-kv --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -i "tunnel" | wc -l)
if [ "$CF_PODS" -ge 1 ]; then
  echo "[OK] Cloudflare Tunnel is Running ($CF_PODS pods active)"
else
  fail_exit "[FAIL] Cloudflare Tunnel pods not running"
fi

echo ""
echo "=================================================================="
echo " [OK] AI Stack End-to-End Pipeline Verification Finished!"
echo "=================================================================="
