#!/usr/bin/env bash
# =====================================================================
#  [92] Export Consolidated ESO Secrets for GCP Secret Manager (JSON)
# =====================================================================
set -euo pipefail

if [ -z "${KUBECONFIG:-}" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: 92-Reveal-ESO-Secrets.sh [gcp-secret-name]

Export ESO-managed Kubernetes Secrets as a consolidated JSON payload
for Google Cloud Secret Manager (default: my-cisc4900-config).

Outputs pure JSON to stdout and instructions/warnings to stderr.
Example:
  ./92-Reveal-ESO-Secrets.sh > secrets.json
EOF
  exit 0
fi

SECRET_NAME="${1:-my-cisc4900-config}"

for cmd in kubectl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[FAIL] $cmd is not installed." >&2
    exit 1
  fi
done

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "[FAIL] Cannot connect to Kubernetes cluster (KUBECONFIG=${KUBECONFIG:-unset})." >&2
  exit 1
fi

python3 - "$SECRET_NAME" <<'PYEOF'
import base64
import json
import subprocess
import sys

gcp_secret_name = sys.argv[1]

CANONICAL_SOURCES = [
    ("tailscale_client_id", [("tailscale", "operator-oauth", "client_id")]),
    ("tailscale_client_secret", [("tailscale", "operator-oauth", "client_secret")]),

    ("cf_account_id", [("external-secrets", "my-cloudflare-config", "MY_ACCOUNT_ID")]),
    ("cf_kv_namespace_id", [("external-secrets", "my-cloudflare-config", "MY_KV_NAMESPACE_ID")]),
    ("cf_api_token", [("external-secrets", "my-cloudflare-config", "MY_API_TOKEN")]),
    ("cf_tunnel_id", [("cloudflare-kv", "cloudflare-kv-secret", "CLOUDFLARE_TUNNEL_ID")]),

    ("juicefs_username", [("kube-system", "my-cloudflare-juicefs-config", "username")]),
    ("juicefs_password", [("kube-system", "my-cloudflare-juicefs-config", "password")]),
    ("juicefs_name", [("kube-system", "my-cloudflare-juicefs-config", "name")]),
    ("juicefs_metaurl", [("kube-system", "my-cloudflare-juicefs-config", "metaurl")]),
    ("juicefs_storage", [("kube-system", "my-cloudflare-juicefs-config", "storage")]),
    ("juicefs_bucket", [("kube-system", "my-cloudflare-juicefs-config", "bucket")]),
    ("juicefs_access_key", [("kube-system", "my-cloudflare-juicefs-config", "access-key")]),
    ("juicefs_secret_key", [("kube-system", "my-cloudflare-juicefs-config", "secret-key")]),

    ("qdrant_key", [("qdrant", "my-qdrant-config", "MY-QDRANT-KEY")]),
    ("qdrant_read_only_key", [("qdrant", "my-qdrant-config", "MY-QDRANT-READ-ONLY-KEY")]),

    ("argocd_admin_password", [("argocd", "argocd-secret", "admin.password")]),

    ("llamacpp_api_key", [("llamacpp-rocm", "llamacpp-api-key", "api-key")]),

    ("litellm_username", [
        ("litellm", "my-litellm-postgres-config", "username"),
        ("grafana", "grafana-admin-credentials", "admin-user"),
    ]),
    ("litellm_password", [
        ("litellm", "my-litellm-postgres-config", "password"),
        ("grafana", "grafana-admin-credentials", "admin-password"),
    ]),
    ("litellm_database_url", [("litellm", "my-litellm-postgres-config", "database-url")]),
    ("litellm_master_key", [("litellm", "my-litellm-postgres-config", "master-key")]),

    ("openwebui_openai_api_keys", [("open-webui", "my-open-webui-secret", "OPENAI_API_KEYS")]),
    ("openwebui_secret_key", [("open-webui", "my-open-webui-secret", "WEBUI_SECRET_KEY")]),
    ("openwebui_db_username", [("open-webui", "my-open-webui-postgres-config", "username")]),
    ("openwebui_db_password", [("open-webui", "my-open-webui-postgres-config", "password")]),
    ("openwebui_db_url", [("open-webui", "my-open-webui-postgres-config", "DATABASE_URL")]),
    ("openwebui_vector_db", [("open-webui", "my-open-webui-qdrant-config", "VECTOR_DB")]),
    ("openwebui_qdrant_uri", [("open-webui", "my-open-webui-qdrant-config", "QDRANT_URI")]),
    ("openwebui_qdrant_api_key", [("open-webui", "my-open-webui-qdrant-config", "QDRANT_API_KEY")]),
]

secret_cache = {}


def get_secret_data(ns, name):
    key = (ns, name)
    if key not in secret_cache:
        res = subprocess.run(
            ["kubectl", "get", "secret", name, "-n", ns, "-o", "json"],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            secret_cache[key] = None
        else:
            raw = json.loads(res.stdout).get("data") or {}
            secret_cache[key] = {
                k: base64.b64decode(v).decode("utf-8", errors="replace")
                for k, v in raw.items()
            }
    return secret_cache[key]


print(f"""=====================================================================
 [92] Exporting ESO Secrets for '{gcp_secret_name}'
=====================================================================""", file=sys.stderr, flush=True)

result = {}
missing = []

for prop_name, candidates in CANONICAL_SOURCES:
    value = None
    for ns, sec_name, key_name in candidates:
        data = get_secret_data(ns, sec_name)
        if data is not None and key_name in data:
            value = data[key_name]
            break
    if value is None and prop_name in ("litellm_username", "litellm_password"):
        falco_data = get_secret_data("falco", "falco-falcosidekick-ui-secret")
        if falco_data and ":" in falco_data.get("FALCOSIDEKICK_UI_USER", ""):
            u, p = falco_data["FALCOSIDEKICK_UI_USER"].split(":", 1)
            value = u if prop_name == "litellm_username" else p
    if value is not None:
        result[prop_name] = value
    else:
        ns, sec, key = candidates[0]
        missing.append(f"{prop_name} ({ns}/{sec}[{key}])")

# Dynamically append any extra ExternalSecret properties referencing gcp_secret_name
es_res = subprocess.run(
    ["kubectl", "get", "externalsecret", "-A", "-o", "json"],
    capture_output=True,
    text=True,
)
if es_res.returncode == 0:
    for es in json.loads(es_res.stdout).get("items", []):
        ns = es.get("metadata", {}).get("namespace", "")
        spec = es.get("spec", {})
        target_name = spec.get("target", {}).get("name") or es.get("metadata", {}).get("name", "")
        for entry in spec.get("data") or []:
            remote_ref = entry.get("remoteRef") or {}
            prop = remote_ref.get("property")
            sec_key = entry.get("secretKey")
            if remote_ref.get("key") != gcp_secret_name or not prop or not sec_key or prop in result:
                continue
            data = get_secret_data(ns, target_name)
            if data is not None and sec_key in data:
                result[prop] = data[sec_key]
                missing = [m for m in missing if not m.startswith(f"{prop} ")]

if not result:
    print(f"[FAIL] No ESO secrets found in Kubernetes for '{gcp_secret_name}'.", file=sys.stderr)
    sys.exit(1)

print(json.dumps(result, indent=2, ensure_ascii=False), flush=True)

if missing:
    print(f"[WARN] Exported {len(result)} keys; missing {len(missing)} key(s):", file=sys.stderr)
    for item in missing:
        print(f"  - {item}", file=sys.stderr)
else:
    print(f"""=====================================================================
 [OK] Successfully exported {len(result)} secret keys
 Next Steps: Upload to Google Cloud Secret Manager
=====================================================================
 1. Open: https://console.cloud.google.com/security/secret-manager/secrets
 2. Click "Create secret", set Name to: {gcp_secret_name}
    (If '{gcp_secret_name}' already exists, open it and click "New version".)
 3. Copy the JSON output above (including the enclosing {} braces) and paste it
    into "Secret value" (or upload JSON file on Google Cloud Secret Manager.)
 4. Click "Create secret" / "Add new version".
    * Tip: Disable or destroy older versions to stay within the
      GCP Free Tier limit (<= 6 active secret versions).
=====================================================================""", file=sys.stderr)
PYEOF