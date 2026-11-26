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

echo "=================================================================="
echo " [103] Qdrant Vector Search & Closed-Loop RAG QA Benchmark"
echo " Testing: Collection Ingestion, Vector Cosine Search & LLM RAG Loop"
echo "=================================================================="

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

QDRANT_API_KEY="${QDRANT_API_KEY:-$(kubectl get secret -n qdrant my-qdrant-config -o jsonpath='{.data.MY-QDRANT-KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"
LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"

QDRANT_IP=$(kubectl get svc -n qdrant qdrant -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
            kubectl get svc -n qdrant -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
             kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -z "$QDRANT_IP" ]; then
  fail_exit "[FAIL] Qdrant service IP not found."
fi

COLLECTION_NAME="cisc4900_rag_eval"
echo "Qdrant Endpoint: http://${QDRANT_IP}:6333"

# Step 1: Initialize temporary evaluation collection
echo ""
echo "--- 1. Initializing Benchmark Collection ($COLLECTION_NAME) ---"
curl -s -X DELETE -H "api-key: ${QDRANT_API_KEY}" "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}" >/dev/null 2>&1 || true

INIT_RES=$(curl -s -X PUT -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 4, "distance": "Cosine"}}' \
  "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}")

if echo "$INIT_RES" | grep -q '"status":"ok"'; then
  echo "[OK] Collection $COLLECTION_NAME created successfully."
else
  fail_exit "[FAIL] Failed to create collection: $INIT_RES"
fi

# Step 2: Upsert sample knowledge embeddings
echo ""
echo "--- 2. Upserting Knowledge Base Documents with Embeddings ---"
UPSERT_PAYLOAD='{
  "points": [
    {
      "id": 1,
      "vector": [0.95, 0.05, 0.02, 0.01],
      "payload": {
        "topic": "hardware",
        "fact": "The CISC4900 cluster computing core is powered by AMD Radeon 8060S APU with 62GB unified VRAM."
      }
    },
    {
      "id": 2,
      "vector": [0.03, 0.94, 0.04, 0.02],
      "payload": {
        "topic": "network",
        "fact": "The public web endpoint is open-webui.kung.nyc secured via Cloudflare Zero Trust tunnel."
      }
    },
    {
      "id": 3,
      "vector": [0.02, 0.03, 0.95, 0.04],
      "payload": {
        "topic": "database",
        "fact": "LiteLLM gateway uses PostgreSQL CloudNativePG cluster for audit logging and API tracking."
      }
    }
  ]
}'

UPSERT_RES=$(curl -s -X PUT -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
  -d "$UPSERT_PAYLOAD" \
  "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}/points?wait=true")

if echo "$UPSERT_RES" | grep -q '"status":"completed"'; then
  echo "[OK] 3 Knowledge Base points indexed successfully."
else
  fail_exit "[FAIL] Upsert failed: $UPSERT_RES"
fi

# Step 3: Perform Vector Similarity Retrieval
echo ""
echo "--- 3. Executing Vector Similarity Search (Top-K Cosine) ---"
SEARCH_PAYLOAD='{
  "vector": [0.93, 0.06, 0.01, 0.01],
  "limit": 1,
  "with_payload": true
}'

SEARCH_RES=$(curl -s -X POST -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
  -d "$SEARCH_PAYLOAD" \
  "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}/points/search")

SCORE=$(echo "$SEARCH_RES" | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{data['result'][0]['score']:.4f}\")" 2>/dev/null || echo "0.0")
RETRIEVED_FACT=$(echo "$SEARCH_RES" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result'][0]['payload']['fact'])" 2>/dev/null || echo "none")

echo "Query Vector Target: Hardware Topic [0.93, 0.06, 0.01, 0.01]"
echo "Retrieved Fact: \"$RETRIEVED_FACT\""
echo "Cosine Similarity Score: $SCORE"

if [ "$(echo "$SCORE > 0.85" | python3 -c "import sys; print(1 if eval(input()) else 0)")" -eq 1 ]; then
  echo "[OK] Vector Similarity Search Accuracy: 100% (High Confidence)"
else
  curl -s -X DELETE -H "api-key: ${QDRANT_API_KEY}" "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}" >/dev/null 2>&1 || true
  fail_exit "[FAIL] Retrieval score below threshold ($SCORE <= 0.85)"
fi

# Step 4: End-to-End RAG QA with LLM (if model available)
echo ""
echo "--- 4. End-to-End RAG QA with LLM Generation ---"
LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
LLAMA_READY=false
if [ -n "$LLAMA_IP" ]; then
  HEALTH=$(curl -s --max-time 3 "http://${LLAMA_IP}:8080/health" 2>/dev/null || echo "not_ready")
  if echo "$HEALTH" | grep -q "ok\|status"; then
    LLAMA_READY=true
  fi
fi

if [ "$LLAMA_READY" = "true" ] && [ -n "$LITELLM_IP" ]; then
  echo "Prompting LiteLLM with Retrieved Context..."
  START_TIME=$(date +%s%N)
  RAG_PROMPT="Context: ${RETRIEVED_FACT}\nQuestion: What GPU powers the CISC4900 cluster? Answer concisely."
  
  if [ -n "$1" ]; then
    ACTIVE_MODEL="$1"
  else
    ACTIVE_MODEL=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "http://${LITELLM_IP}:4000/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | grep -i "0.5b\|fast\|mini" | head -n 1 | sed 's/"id":"//;s/"//')
    if [ -z "$ACTIVE_MODEL" ]; then
      ACTIVE_MODEL=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "http://${LITELLM_IP}:4000/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"//;s/"//')
    fi
  fi
  [ -z "$ACTIVE_MODEL" ] && ACTIVE_MODEL="qwen2.5-0.5b-instruct"
  RAG_RESPONSE=$(curl -s --max-time 30 \
    -H "Authorization: Bearer ${LITELLM_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${ACTIVE_MODEL}\", \"messages\": [{\"role\": \"user\", \"content\": \"${RAG_PROMPT}\"}], \"max_tokens\": 30}" \
    "http://${LITELLM_IP}:4000/v1/chat/completions" 2>/dev/null || echo "error")
  END_TIME=$(date +%s%N)
  RAG_MS=$(( (END_TIME - START_TIME) / 1000000 ))
  
  ANSWER=$(echo "$RAG_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['choices'][0]['message']['content'].strip())" 2>/dev/null || echo "$RAG_RESPONSE")
  echo "RAG Answer: \"$ANSWER\""
  echo "Total RAG Latency: ${RAG_MS} ms"
  
  if echo "$ANSWER" | grep -qi "8060S\|Radeon"; then
    echo "[PASS] Ground Truth Verification: Model answered accurately based on retrieved vector context!"
  else
    curl -s -X DELETE -H "api-key: ${QDRANT_API_KEY}" "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}" >/dev/null 2>&1 || true
    fail_exit "[FAIL] Ground Truth Verification failed: Model answer did not match expected context (Answer: $ANSWER)"
  fi
else
  echo "[NOTICE] llama.cpp is currently awaiting a model in /models."
  echo "         Qdrant vector ingestion and top-1 cosine retrieval passed with Score: $SCORE."
  echo "         Once a model is loaded via ./Menu.sh 100, this test will execute the full LLM answer validation."
fi

# Cleanup
curl -s -X DELETE -H "api-key: ${QDRANT_API_KEY}" "http://${QDRANT_IP}:6333/collections/${COLLECTION_NAME}" >/dev/null 2>&1 || true

echo ""
echo "=================================================================="
echo " [OK] RAG Vector Benchmark Completed Successfully!"
echo "=================================================================="
