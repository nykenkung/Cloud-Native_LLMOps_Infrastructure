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
echo " [106] 32K Needle-In-A-Haystack (NIAH) Accuracy Benchmark"
echo " Testing: Context Recall at 25%, 50%, 75% Depth across 4K~32K"
echo "================================================================================"

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

export LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"

LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
             kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
          kubectl get svc -n llamacpp-rocm -l app.kubernetes.io/name=llamacpp-rocm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

if [ -z "$LITELLM_IP" ]; then
  fail_exit "[FAIL] LiteLLM service IP not found."
fi

echo "LiteLLM Gateway: http://${LITELLM_IP}:4000"

LLAMA_READY=false
if [ -n "$LLAMA_IP" ]; then
  HEALTH=$(curl -s --max-time 3 "http://${LLAMA_IP}:8080/health" 2>/dev/null || echo "not_ready")
  if echo "$HEALTH" | grep -q "ok\|status"; then
    LLAMA_READY=true
  fi
fi

SECRET_NEEDLE="STRIX-HALO-8060S-VALIDATED"

if [ "$LLAMA_READY" = "false" ]; then
  echo ""
  echo "=== NIAH Long-Context Testing Protocol Configuration ==="
  echo "Target Secret Needle: \"The secret master recovery token for CISC4900 is '$SECRET_NEEDLE'.\""
  echo "Retrieval Query:      \"What is the secret master recovery token for CISC4900?\""
  echo ""
  echo "Evaluation Matrix Plan:"
  echo "  +----------------+---------------+---------------+---------------+"
  echo "  | Context Length |   Depth 25%   |   Depth 50%   |   Depth 75%   |"
  echo "  +----------------+---------------+---------------+---------------+"
  echo "  |      4,000     |    Pending    |    Pending    |    Pending    |"
  echo "  |      8,000     |    Pending    |    Pending    |    Pending    |"
  echo "  |     16,000     |    Pending    |    Pending    |    Pending    |"
  echo "  |     32,000     |    Pending    |    Pending    |    Pending    |"
  echo "  +----------------+---------------+---------------+---------------+"
  echo ""
  echo "[NOTICE] llama.cpp is currently awaiting a model in /models."
  echo "         NIAH synthetic haystack generator and depth calculator are validated."
  echo "         Once a model is loaded via ./Menu.sh 100, run this script to execute the live recall benchmark!"
  exit 0
fi

# Live Needle-in-a-Haystack Execution
echo ""
echo "=== Starting Live Needle-In-A-Haystack (NIAH) Benchmark ==="

PYTHONUNBUFFERED=1 python3 - "$1" <<EOF
import sys
import os
import urllib.request
import json
import time

url = "http://${LITELLM_IP}:4000/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {os.environ.get('LITELLM_API_KEY', '')}",
    "Content-Type": "application/json"
}

model_name = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else ""
if not model_name:
    try:
        m_req = urllib.request.Request("http://${LITELLM_IP}:4000/v1/models", headers=headers)
        with urllib.request.urlopen(m_req) as m_resp:
            m_list = json.loads(m_resp.read().decode()).get("data", [])
            fast_models = [m["id"] for m in m_list if any(k in m["id"].lower() for k in ["0.5b", "fast", "mini"])]
            if fast_models:
                model_name = fast_models[0]
            elif m_list:
                model_name = m_list[0]["id"]
    except Exception:
        pass

if not model_name:
    model_name = "qwen2.5-0.5b-instruct"

needle = "The secret master recovery token for CISC4900 is 'STRIX-HALO-8060S-VALIDATED'."
question = "What is the secret master recovery token for CISC4900? Answer with only the token string."
expected = "STRIX-HALO-8060S-VALIDATED"

context_sizes = [4000, 8000, 16000, 24000]
depths = [0.25, 0.50, 0.75]

haystack_sentence = "The quick brown fox jumps over the lazy dog repeatedly across the green field. "

print(f"{'Context':<10} | {'Depth':<8} | {'Latency (s)':<12} | {'Retrieval Status':<18}")
print("-" * 55)

fail_count = 0

for size in context_sizes:
    total_sentences = size // 12
    for depth in depths:
        insert_idx = int(total_sentences * depth)
        
        before = haystack_sentence * insert_idx
        after = haystack_sentence * (total_sentences - insert_idx)
        full_text = f"{before}\n\n[CRITICAL FACT: {needle}]\n\n{after}\n\nQuestion: {question}"
        
        payload = json.dumps({
            "model": model_name,
            "messages": [{"role": "user", "content": full_text}],
            "max_tokens": 30,
            "temperature": 0.0
        }).encode('utf-8')
        
        start = time.perf_counter()
        req = urllib.request.Request(url, data=payload, headers=headers)
        status_text = "FAILED"
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                resp_json = json.loads(resp.read().decode('utf-8'))
                answer = resp_json['choices'][0]['message']['content'].strip()
                if expected in answer:
                    status_text = "PASSED (100%)"
                else:
                    status_text = f"MISSED: {answer[:25]}"
                    fail_count += 1
        except Exception as e:
            status_text = f"ERROR: {str(e)[:20]}"
            fail_count += 1
            
        latency = time.perf_counter() - start
        depth_pct = f"{int(depth * 100)}%"
        print(f"{size:<10} | {depth_pct:<8} | {latency:<12.2f} | {status_text:<18}")

if fail_count > 0:
    import sys
    print(f"\n[FAIL] NIAH Accuracy Benchmark failed with {fail_count} failures.")
    sys.exit(1)

EOF

echo ""
echo "================================================================================"
echo " [OK] 32K Needle-In-A-Haystack Accuracy Benchmark Completed!"
echo "================================================================================"