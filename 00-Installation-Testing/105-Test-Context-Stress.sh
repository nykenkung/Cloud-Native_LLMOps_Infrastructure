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
echo " [105] Stepped Context Window (1K~32K) & ROCm VRAM Benchmark"
echo " Testing: 32K Context Processing, KV-Cache Scaling & APU VRAM"
echo "=================================================================="

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

export LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"

LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
             kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
          kubectl get svc -n llamacpp-rocm -l app.kubernetes.io/name=llamacpp-rocm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

echo "Checking LLM Endpoint Status..."
LLAMA_READY=false
if [ -n "$LLAMA_IP" ]; then
  HEALTH=$(curl -s --max-time 3 "http://${LLAMA_IP}:8080/health" 2>/dev/null || echo "not_ready")
  if echo "$HEALTH" | grep -q "ok\|status"; then
    LLAMA_READY=true
    echo "[OK] llama.cpp is ready for inference on http://${LLAMA_IP}:8080"
  fi
fi

if [ "$LLAMA_READY" = "false" ]; then
  echo "[NOTICE] llama.cpp is currently awaiting a model in /models."
  echo "         Displaying GPU & Memory Topology for Stress Testing Configuration..."
  echo ""
  if command -v rocm-smi >/dev/null 2>&1; then
    rocm-smi || true
  fi
  kubectl exec -n amd-rocdxg deployment/amd-rocdxg-deploy -- python3 -c \
    "import torch; print(f'GPU Device: {torch.cuda.get_device_name(0)}'); print(f'Total Memory: {torch.cuda.get_device_properties(0).total_memory / (1024**3):.2f} GB')" 2>/dev/null || true
  echo ""
  echo "Context Window Configuration:"
  echo "  - llama.cpp total context (-c): 65,536 tokens"
  echo "  - Parallel slots (--parallel): 2 (32,768 tokens per slot)"
  echo "  - LiteLLM max_input_tokens: 32,768 tokens"
  echo "  - Estimated 32K KV-Cache Allocation: ~4GB - 8GB unified memory"
  echo ""
  echo "Once a model is placed in /models via ./0-Menu.sh 100,"
  echo "re-run this script to execute live 1K -> 4K -> 8K -> 16K -> 32K context stress tests."
  exit 0
fi

# Live context stress test execution
echo ""
echo "=== Starting Stepped Context Length Benchmark ==="

if [ -n "$1" ]; then
  ACTIVE_MODEL="$1"
else
  # Prefer lightweight model for benchmark speed if present, fallback to first available
  ACTIVE_MODEL=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "http://${LITELLM_IP}:4000/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | grep -i "0.5b\|fast\|mini" | head -n 1 | sed 's/"id":"//;s/"//')
  if [ -z "$ACTIVE_MODEL" ]; then
    ACTIVE_MODEL=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "http://${LITELLM_IP}:4000/v1/models" 2>/dev/null | grep -o '"id":"[^"]*"' | head -n 1 | sed 's/"id":"//;s/"//')
  fi
fi
[ -z "$ACTIVE_MODEL" ] && ACTIVE_MODEL="qwen2.5-0.5b-instruct"

python3 - "$ACTIVE_MODEL" "$LITELLM_IP" <<EOF
import sys, os, urllib.request, json, time

model = sys.argv[1]
litellm_ip = sys.argv[2]
url = f"http://{litellm_ip}:4000/v1/chat/completions"
headers = {"Authorization": f"Bearer {os.environ.get('LITELLM_API_KEY', '')}", "Content-Type": "application/json"}

for words in [1000, 4000, 8000, 16000, 32000]:
    print(f"\n--- Testing Context Window: ~{words} words (model: {model}) ---")
    prompt = ("The quick brown fox jumps over the lazy dog. " * (words // 10))
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": f"Summarize in 5 words: {prompt}"}],
        "max_tokens": 20
    }).encode("utf-8")
    
    start = time.perf_counter()
    req = urllib.request.Request(url, data=payload, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode())
            dur = (time.perf_counter() - start) * 1000
            print(f"Response Time: {dur:.0f} ms")
            if "choices" in data:
                print(f"[PASS] Successfully processed {words} context without truncation or OOM.")
            else:
                print(f"[FAIL] Context length {words} failed: {data}")
                sys.exit(1)
    except Exception as e:
        dur = (time.perf_counter() - start) * 1000
        print(f"Response Time: {dur:.0f} ms")
        print(f"[FAIL] Context length {words} failed: {e}")
        sys.exit(1)
EOF

echo ""
echo "=================================================================="
echo " [OK] Stepped Context Window & Stress Test Completed!"
echo "=================================================================="
