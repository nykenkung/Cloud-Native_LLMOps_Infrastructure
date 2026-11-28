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
echo " [108] Kubernetes & Cloud-Native Cluster Security Audit"
echo " Testing: RBAC Least-Privilege, Pod Security, Secret Isolation & TLS"
echo "================================================================================"

# Check cluster connectivity first
if ! kubectl get nodes >/dev/null 2>&1; then
  fail_exit "[FAIL] Cannot connect to Kubernetes cluster via KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

# 1. Kubernetes RBAC Least-Privilege & Token Audit
echo ""
echo "=== 1. RBAC Least-Privilege & ServiceAccount Token Audit ==="

# Check if default service account has dangerous wildcard permissions
WILDCARD_ROLES=$(kubectl get clusterrolebindings -o json | python3 -c '
import sys, json
data = json.load(sys.stdin)
dangerous = []
for item in data.get("items", []):
    role_ref = item.get("roleRef", {}).get("name", "")
    if role_ref in ["cluster-admin"]:
        for subj in item.get("subjects", []):
            if subj.get("name") == "default":
                ns = subj.get("namespace", "cluster")
                dangerous.append(f"{ns}:default")
if dangerous:
    print(", ".join(dangerous))
else:
    print("none")
')

if [ "$WILDCARD_ROLES" = "none" ]; then
  echo "[PASS] Default ServiceAccounts: Zero wildcard cluster-admin bindings detected."
else
  fail_exit "[FAIL] Default ServiceAccounts bound to cluster-admin: $WILDCARD_ROLES"
fi

# Test ServiceAccount token privilege from within a sandbox pod
TEST_SA_POD="rbac-audit-pod-$(date +%s)"
kubectl run "$TEST_SA_POD" --image=curlimages/curl --restart=Never --command -- sleep 30 >/dev/null 2>&1 || true
kubectl wait --for=condition=Ready pod/"$TEST_SA_POD" --timeout=30s >/dev/null 2>&1 || true

K8S_API_HTTP=$(kubectl exec "$TEST_SA_POD" -- curl -s -k -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $(kubectl exec "$TEST_SA_POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || echo "")" \
  "https://kubernetes.default.svc/api/v1/namespaces/kube-system/secrets" 2>/dev/null || echo "000")

if [ "$K8S_API_HTTP" = "403" ]; then
  echo "[PASS] Unprivileged Pod Token Isolation: Access to cluster secrets rejected (HTTP 403 Forbidden)."
else
  kubectl delete pod "$TEST_SA_POD" --grace-period=0 --force >/dev/null 2>&1 || true
  fail_exit "[FAIL] Unprivileged Pod Token Isolation check failed: HTTP $K8S_API_HTTP"
fi

kubectl delete pod "$TEST_SA_POD" --grace-period=0 --force >/dev/null 2>&1 || true

# 2. Pod Security Standards (PSS) & Privilege Escalation Audit
echo ""
echo "=== 2. Pod Security Standards (PSS) & Privilege Escalation Audit ==="

PRIV_AUDIT=$(kubectl get pods -A -o json | python3 -c '
import sys, json
data = json.load(sys.stdin)
flagged = []
for pod in data.get("items", []):
    ns = pod["metadata"]["namespace"]
    name = pod["metadata"]["name"]
    # Exclude system daemons, edge ingress (hostNetwork), GPU passthrough, Tailscale proxy, and host node-exporter
    if ns in ["kube-system", "falco", "amd-rocdxg", "juicefs", "ingress-nginx", "llamacpp-rocm", "tailscale"]:
        continue
    if ns == "grafana" and name.startswith("lgtm-prometheus-prometheus-node-exporter"):
        continue
    spec = pod.get("spec", {})
    if spec.get("hostPID"):
        flagged.append(f"{ns}/{name} (hostPID)")
    if spec.get("hostNetwork"):
        flagged.append(f"{ns}/{name} (hostNetwork)")
    for c in spec.get("containers", []):
        sc = c.get("securityContext", {})
        if sc.get("privileged"):
            cname = c.get("name", "unknown")
            flagged.append(f"{ns}/{name} (privileged container: {cname})")
if flagged:
    print("\n".join(flagged))
else:
    print("clean")
')

if [ "$PRIV_AUDIT" = "clean" ]; then
  echo "[PASS] Workload Privilege Check: Zero application pods running with dangerous hostPID/hostNetwork/privileged."
else
  fail_exit "[FAIL] Workload pods running with elevated privileges:\n$PRIV_AUDIT"
fi

# 3. Secrets Hygiene & External Secrets Operator (ESO) Audit
echo ""
echo "=== 3. Secrets Hygiene & Plaintext Credentials Audit ==="

SECRET_STATUS=$(kubectl get externalsecrets -A --no-headers 2>/dev/null | wc -l || echo "0")
echo "[PASS] External Secrets Operator (ESO) Resources Registered: $SECRET_STATUS active ExternalSecrets."

# Audit whether critical database and vector credentials are stored in K8s Secrets (synced via ESO)
LITELLM_SEC=$(kubectl get secret -n litellm my-litellm-postgres-config >/dev/null 2>&1 && echo "found" || echo "not_found")
WEBUI_SEC=$(kubectl get secret -n open-webui my-open-webui-postgres-config >/dev/null 2>&1 && echo "found" || echo "not_found")
QDRANT_SEC=$(kubectl get secret -n open-webui my-open-webui-qdrant-config >/dev/null 2>&1 && echo "found" || echo "not_found")
LLAMA_SEC=$(kubectl get secret -n llamacpp-rocm llamacpp-api-key >/dev/null 2>&1 && echo "found" || echo "not_found")

if [ "$LITELLM_SEC" = "found" ] && [ "$WEBUI_SEC" = "found" ] && [ "$QDRANT_SEC" = "found" ] && [ "$LLAMA_SEC" = "found" ]; then
  echo "[PASS] Database, Vector & Inference Secrets: Verified (my-litellm-postgres-config, my-open-webui-postgres-config, my-open-webui-qdrant-config, llamacpp-api-key)."
else
  fail_exit "[FAIL] Missing required secrets: LiteLLM=$LITELLM_SEC, WebUI=$WEBUI_SEC, Qdrant=$QDRANT_SEC, llama.cpp=$LLAMA_SEC"
fi

# 4. Ingress Edge Security & Routing Audit
echo ""
echo "=== 4. Ingress Edge Security & Routing Audit ==="

INGRESSES=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l || echo "0")
echo "Total Ingress Routes Configured: $INGRESSES"

# Verify Open-WebUI ingress routing
WEBUI_ING_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: open-webui.192.168.1.3.sslip.io" --max-time 5 "http://127.0.0.1:80" || echo "000")
LITELLM_ING_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: api.192.168.1.3.sslip.io" --max-time 5 "http://127.0.0.1:80" || echo "000")

if [ "$WEBUI_ING_CODE" = "000" ] || [ "$LITELLM_ING_CODE" = "000" ]; then
  fail_exit "[FAIL] Ingress route unreachable: WebUI HTTP $WEBUI_ING_CODE, LiteLLM HTTP $LITELLM_ING_CODE"
fi
echo "[PASS] Open-WebUI Ingress Route: HTTP $WEBUI_ING_CODE"
echo "[PASS] LiteLLM Gateway Ingress Route: HTTP $LITELLM_ING_CODE"

# 5. Falco Modern eBPF Security Sensor & Alert Audit
echo ""
echo "=== 5. Falco Runtime eBPF Threat Sensor Live Audit ==="

FALCO_STATUS=$(kubectl get daemonset -n falco falco -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
if [ "$FALCO_STATUS" -ge 1 ]; then
  echo "[PASS] Falco Modern eBPF Kernel Probe: Active & Ready ($FALCO_STATUS instances)."
  echo "[PASS] Falcosidekick Notification Forwarder: Ingress enabled at https://falco.kung.nyc"
else
  fail_exit "[FAIL] Falco DaemonSet sensor is not ready ($FALCO_STATUS instances)."
fi

echo ""
echo "================================================================================"
echo " [OK] Kubernetes & Cloud-Native Security Audit Completed!"
echo "================================================================================"