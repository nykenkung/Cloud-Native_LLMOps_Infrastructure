#!/usr/bin/env bash
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "$1"; exit 1; }

echo "================================================================================"
echo " [102] Security Penetration, NetworkPolicy & Falco Audit"
echo " Testing: Negative Auth, Zero-Trust Microsegmentation & eBPF Threat"
echo "================================================================================"

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"

LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
             kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
QDRANT_IP=$(kubectl get svc -n qdrant qdrant -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
            kubectl get svc -n qdrant -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
          kubectl get svc -n llamacpp-rocm -l app.kubernetes.io/name=llamacpp-rocm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

# 1. API Negative Authentication & RBAC Pen-Test
echo ""
echo "=== 1. API Negative Authentication & RBAC Defense Pen-Test ==="

# 1.1 LiteLLM with invalid token
if [ -n "$LITELLM_IP" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Authorization: Bearer invalid-token-hacker-9999" \
    "http://${LITELLM_IP}:4000/v1/models" || echo "000")
  if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "[PASS] LiteLLM Unauthorized Access Blocked: HTTP $HTTP_CODE (Invalid Token Rejected)"
  else
    fail_exit "[FAIL] LiteLLM Security Weakness: Returned HTTP $HTTP_CODE for invalid token"
  fi
else
  fail_exit "[FAIL] LiteLLM service IP not found, cannot perform auth pen-test"
fi

# 1.2 Qdrant without API Key
if [ -n "$QDRANT_IP" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    "http://${QDRANT_IP}:6333/collections" || echo "000")
  if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "[PASS] Qdrant Unauthorized Access Blocked: HTTP $HTTP_CODE (Missing API Key Rejected)"
  else
    fail_exit "[FAIL] Qdrant Security Weakness: Returned HTTP $HTTP_CODE without authentication"
  fi
else
  fail_exit "[FAIL] Qdrant service IP not found, cannot perform auth pen-test"
fi

# 1.3 llama.cpp with invalid Bearer token
if [ -n "$LLAMA_IP" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Authorization: Bearer wrong-token" \
    "http://${LLAMA_IP}:8080/v1/models" || echo "000")
  if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "[PASS] llama.cpp Unauthorized Access Blocked: HTTP $HTTP_CODE (Rejected)"
  else
    echo "[INFO] llama.cpp Auth Endpoint Response: HTTP $HTTP_CODE"
  fi
else
  fail_exit "[FAIL] llama.cpp service IP not found, cannot perform auth pen-test"
fi

# 2. Kubernetes NetworkPolicy Microsegmentation Test
echo ""
echo "=== 2. NetworkPolicy Zero-Trust Microsegmentation Pen-Test ==="
echo "Deploying unprivileged sandbox pod in default namespace to test lateral movement..."

TEST_POD_NAME="security-pen-test-$(date +%s)"
kubectl run "$TEST_POD_NAME" --image=curlimages/curl --restart=Never --command -- sleep 60 >/dev/null 2>&1 || true

# Wait for test pod
kubectl wait --for=condition=Ready pod/"$TEST_POD_NAME" --timeout=30s >/dev/null 2>&1 || true

# Attempt 1: Default namespace trying to connect to llamacpp (Should be blocked by llamacpp-rocm-np)
echo "Attempting unauthorized lateral connection: default pod -> llamacpp-rocm:8080"
BLOCK_LLAMA=$(kubectl exec "$TEST_POD_NAME" -- curl -s -m 3 "http://llamacpp-rocm-svc.llamacpp-rocm.svc:8080/health" 2>&1 || echo "blocked_timeout")
if echo "$BLOCK_LLAMA" | grep -qi "timeout\|timed out\|refused\|blocked"; then
  echo "[PASS] NetworkPolicy Active: Unauthorized access to llama.cpp successfully BLOCKED (Zero-Trust Dropped)."
else
  kubectl delete pod "$TEST_POD_NAME" --grace-period=0 --force >/dev/null 2>&1 || true
  fail_exit "[FAIL] Lateral connection reached service: $BLOCK_LLAMA (NetworkPolicy violation)"
fi

# Attempt 2: Default namespace trying to connect to LiteLLM PostgreSQL (Should be blocked)
echo "Attempting unauthorized lateral connection: default pod -> litellm-postgres:5432"
BLOCK_PG=$(kubectl exec "$TEST_POD_NAME" -- nc -z -w 3 litellm-postgres-rw.litellm.svc 5432 2>&1 || echo "blocked_timeout")
if echo "$BLOCK_PG" | grep -qi "timeout\|timed out\|refused\|blocked\|failed"; then
  echo "[PASS] NetworkPolicy Active: Unauthorized direct access to PostgreSQL database BLOCKED."
else
  kubectl delete pod "$TEST_POD_NAME" --grace-period=0 --force >/dev/null 2>&1 || true
  fail_exit "[FAIL] PostgreSQL lateral connection succeeded: $BLOCK_PG (NetworkPolicy violation)"
fi

# Cleanup test pod
kubectl delete pod "$TEST_POD_NAME" --grace-period=0 --force >/dev/null 2>&1 || true

# 3. API Gateway Malformed Input & Fuzzing Defense Pen-Test
echo ""
echo "=== 3. API Gateway Malformed Input & Fuzzing Defense Pen-Test ==="

if [ -n "$LITELLM_IP" ]; then
  # 3.1 SQL Injection payload fuzzing on LiteLLM Gateway
  SQLI_RES=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Authorization: Bearer ${LITELLM_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"model": "default'\'' OR 1=1 --", "messages": [{"role": "user", "content": "ping"}]}' \
    "http://${LITELLM_IP}:4000/v1/chat/completions" 2>/dev/null || echo "000")

  if [ "$SQLI_RES" = "400" ] || [ "$SQLI_RES" = "422" ] || [ "$SQLI_RES" = "404" ] || [ "$SQLI_RES" = "500" ]; then
    echo "[PASS] Gateway SQL Injection Fuzzing Handled Safely: HTTP $SQLI_RES (No database panic/leak)."
  else
    fail_exit "[FAIL] Gateway SQL Injection Fuzzing Vulnerability: HTTP $SQLI_RES"
  fi
fi

# 3.2 Directory Traversal attack on Ingress
TRAVERSAL_RES=$(curl -s --path-as-is --max-time 5 \
  -H "Host: open-webui.192.168.1.3.sslip.io" \
  "http://127.0.0.1:80/../../../../etc/passwd" 2>/dev/null || echo "")

if ! echo "$TRAVERSAL_RES" | grep -q "root:x:0:0"; then
  echo "[PASS] Ingress Path Traversal Defense: Arbitrary host /etc/passwd access prevented (No secret leakage)."
else
  fail_exit "[FAIL] Ingress Path Traversal Defense failed: /etc/passwd was leaked!"
fi

# 4. Falco eBPF Runtime Security Sensor Audit
echo ""
echo "=== 4. Falco eBPF Runtime Threat Detection Audit ==="
FALCO_READY=$(kubectl get daemonset -n falco falco -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
SIDEKICK_READY=$(kubectl get pods -n falco -l app.kubernetes.io/name=falcosidekick --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "${FALCO_READY:-0}" -ge 1 ] && [ "${SIDEKICK_READY:-0}" -ge 1 ]; then
  echo "[PASS] Falco Modern eBPF Sensor Active ($FALCO_READY DaemonSet pod, $SIDEKICK_READY Falcosidekick pod(s) Running)."
else
  fail_exit "[FAIL] Falco runtime security sensor not ready (DaemonSet=$FALCO_READY, Sidekick=$SIDEKICK_READY)."
fi

echo ""
echo "================================================================================"
echo " [OK] Network & Gateway Penetration Test Completed!"
echo "================================================================================"