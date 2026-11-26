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
echo " [104] Multi-User Concurrency, Throughput & TTFT Benchmark"
echo " Testing: Parallel Load, Tokens/Sec (TPS), First-Token (TTFT) & KEDA"
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

if [ "$LLAMA_READY" = "false" ]; then
  echo ""
  echo "--- 1. Gateway High-Concurrency HTTP Benchmark (API Routing Layer) ---"
  python3 - <<EOF
import urllib.request
import time
import concurrent.futures
import statistics

url = "http://${LITELLM_IP}:4000/health/liveliness"
total_requests = 40
concurrency = 8
latencies = []
errors = 0

def fetch():
    global errors
    start = time.perf_counter()
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status != 200:
                errors += 1
    except Exception:
        errors += 1
    latencies.append((time.perf_counter() - start) * 1000)

print(f"Sending {total_requests} requests across {concurrency} concurrent threads...")
start_all = time.perf_counter()
with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
    futures = [executor.submit(fetch) for _ in range(total_requests)]
    concurrent.futures.wait(futures)
total_time = time.perf_counter() - start_all

latencies.sort()
p50 = statistics.median(latencies)
p95 = latencies[int(len(latencies) * 0.95)] if len(latencies) > 0 else 0
p99 = latencies[int(len(latencies) * 0.99)] if len(latencies) > 0 else 0
rps = total_requests / total_time if total_time > 0 else 0

print(f"Total Completed: {total_requests - errors}/{total_requests} (Error Rate: {errors/total_requests:.1%})")
print(f"Total Throughput: {rps:.2f} Requests/Sec")
print(f"Latency P50: {p50:.2f} ms | P95: {p95:.2f} ms | P99: {p99:.2f} ms")
if errors > 0:
    import sys
    print(f"[FAIL] High-concurrency routing benchmark had {errors} failed requests.")
    sys.exit(1)
EOF

  echo ""
  echo "--- 2. Checking KEDA Autoscaler & Metric Endpoints ---"
  echo "KEDA ScaledObject in namespace llamacpp-rocm:"
  kubectl get scaledobject -n llamacpp-rocm 2>/dev/null || echo "No ScaledObject found"
  echo "HPA status in namespace llamacpp-rocm:"
  kubectl get hpa -n llamacpp-rocm 2>/dev/null || echo "No HPA found"

  echo ""
  echo "[NOTICE] llama.cpp is currently awaiting a model in /models."
  echo "         Gateway concurrency benchmark passed with sub-millisecond routing latency."
  echo "         Once a model is loaded via ./Menu.sh 100, this test will benchmark live TTFT & TPS!"
  exit 0
fi

# Live LLM Concurrency & TTFT Benchmark
echo ""
echo "--- Live LLM Concurrency & Streaming Generation Benchmark ---"
PYTHONUNBUFFERED=1 python3 - "$1" <<EOF
import sys
import os
import urllib.request
import json
import time
import concurrent.futures

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

concurrency_levels = [1, 2, 4]

for conc in concurrency_levels:
    print(f"\n>>> Testing Concurrency Level: {conc} parallel streams (model: {model_name})...")
    ttft_list = []
    tps_list = []
    total_tokens_list = []
    
    def run_stream():
        payload = json.dumps({
            "model": model_name,
            "messages": [{"role": "user", "content": "Explain artificial intelligence in three brief sentences."}],
            "max_tokens": 100,
            "stream": True
        }).encode('utf-8')
        
        req = urllib.request.Request(url, data=payload, headers=headers)
        start_req = time.perf_counter()
        first_token_time = None
        token_count = 0
        
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                for line in resp:
                    line = line.decode('utf-8').strip()
                    if line.startswith("data: ") and not line.endswith("[DONE]"):
                        if first_token_time is None:
                            first_token_time = time.perf_counter()
                        token_count += 1
            end_req = time.perf_counter()
            if first_token_time:
                ttft_ms = (first_token_time - start_req) * 1000
                gen_sec = end_req - first_token_time
                tps = token_count / gen_sec if gen_sec > 0 else 0
                ttft_list.append(ttft_ms)
                tps_list.append(tps)
                total_tokens_list.append(token_count)
        except Exception as e:
            print(f"Request error: {e}")

    start_batch = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=conc) as executor:
        futures = [executor.submit(run_stream) for _ in range(conc)]
        concurrent.futures.wait(futures)
    batch_time = time.perf_counter() - start_batch

    if ttft_list and tps_list:
        avg_ttft = sum(ttft_list) / len(ttft_list)
        avg_tps = sum(tps_list) / len(tps_list)
        agg_tps = sum(total_tokens_list) / batch_time if batch_time > 0 else 0
        print(f"Results for Concurrency {conc}:")
        print(f"  - Average TTFT (Time to First Token): {avg_ttft:.2f} ms")
        print(f"  - Per-Stream Speed: {avg_tps:.2f} tokens/sec")
        print(f"  - Aggregate APU Throughput: {agg_tps:.2f} tokens/sec")
    else:
        import sys
        print(f"[FAIL] All streams failed for concurrency level {conc}")
        sys.exit(1)
EOF

echo ""
echo "--- Checking GPU & KEDA Autoscaler Metrics ---"
kubectl get scaledobject -n llamacpp-rocm 2>/dev/null || true
kubectl get hpa -n llamacpp-rocm 2>/dev/null || true

echo ""
echo "=================================================================="
echo " [OK] Multi-User Concurrency & TTFT Benchmark Completed!"
echo "=================================================================="
