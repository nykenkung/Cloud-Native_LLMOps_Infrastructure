#!/usr/bin/env bash
# =====================================================================
#  [3] Kubernetes (K3s) Cluster
#  Lightweight K3s, kubeconfig & ~/.bashrc Integration
#
#  Usage: ./03-Kubernetes.sh {-install|-test|-restart|-uninstall}
# =====================================================================
set -euo pipefail

if [ -z "${KUBECONFIG:-}" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "$1" >&2; exit 1; }
warn_msg()  { echo -e "$1"; }

resolve_config_dir() {
  if [ -d "$HOME/03-Kubernetes" ]; then
    echo "$HOME/03-Kubernetes"
  elif [ -d "$HOME/3-Kubernetes" ]; then
    echo "$HOME/3-Kubernetes"
  else
    echo "$HOME/03-Kubernetes"
  fi
}

install_k3s_config() {
  local dir
  dir="$(resolve_config_dir)"
  if [ -f "$dir/config.yaml" ]; then
    echo "Installing /etc/rancher/k3s/config.yaml from $dir/config.yaml..."
    sudo mkdir -p /etc/rancher/k3s
    # Strip Windows CRLF line endings if copied from Windows via Copy-SSH.bat
    sed 's/\r$//' "$dir/config.yaml" | sudo tee /etc/rancher/k3s/config.yaml >/dev/null
    sudo chmod 644 /etc/rancher/k3s/config.yaml
  else
    warn_msg "[WARN] $dir/config.yaml not found. K3s will use default configuration."
  fi
}

sync_kubeconfig() {
  mkdir -p "$HOME/.kube"
  if sudo test -f "/etc/rancher/k3s/k3s.yaml"; then
    echo "Installing ~/.kube/config from /etc/rancher/k3s/k3s.yaml..."
    sudo install -m 600 -o "$(id -u)" -g "$(id -g)" /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  else
    fail_exit "[FAIL] /etc/rancher/k3s/k3s.yaml not found."
  fi
  export KUBECONFIG="$HOME/.kube/config"
}

wait_for_k3s_api() {
  echo "Waiting for K3s API server to be ready..."
  for i in $(seq 1 30); do
    if kubectl get --raw /readyz >/dev/null 2>&1; then
      echo "[OK] K3s API server is ready."
      return 0
    fi
    sleep 2
  done
  fail_exit "[FAIL] Timed out waiting for K3s API server (/readyz) after 60s."
}

do_install() {
  # Prerequisite checks for a fresh host
  command -v sudo >/dev/null 2>&1    || fail_exit "[FAIL] sudo is not installed."
  command -v curl >/dev/null 2>&1    || fail_exit "[FAIL] curl is not installed. Please install curl first."
  command -v python3 >/dev/null 2>&1 || fail_exit "[FAIL] python3 is not installed. Please install python3 first."

  install_k3s_config

  if ! command -v k3s >/dev/null 2>&1; then
    echo "Installing K3s (without Traefik)..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
  else
    echo "K3s is already installed."
  fi

  sync_kubeconfig

  if [ ! -f "$HOME/.bashrc" ] || ! grep -q "KUBECONFIG" "$HOME/.bashrc"; then
    echo 'export KUBECONFIG=$HOME/.kube/config' >> "$HOME/.bashrc"
  fi

  wait_for_k3s_api

  echo "Exporting K3s OIDC metadata (openid-configuration & jwks.json)..."
  mkdir -p "$HOME/K8s-OIDC-Provider/.well-known"
  local oidc_base="https://nykenkung.github.io/Cloud-Native_LLMOps_Infrastructure/K8s-OIDC-Provider"
  local oidc_raw jwks_raw

  oidc_raw="$(kubectl get --raw /.well-known/openid-configuration)"
  [ -n "$oidc_raw" ] || fail_exit "[FAIL] Empty response from /.well-known/openid-configuration"

  printf '%s' "$oidc_raw" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['issuer'] = '${oidc_base}'
d['jwks_uri'] = '${oidc_base}/jwks.json'
print(json.dumps(d, indent=2))
" > "$HOME/K8s-OIDC-Provider/.well-known/openid-configuration"

  jwks_raw="$(kubectl get --raw /openid/v1/jwks)"
  [ -n "$jwks_raw" ] || fail_exit "[FAIL] Empty response from /openid/v1/jwks"

  printf '%s' "$jwks_raw" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'keys' in d and len(d['keys']) > 0, 'JWKS missing keys'
print(json.dumps(d, indent=2))
" > "$HOME/K8s-OIDC-Provider/jwks.json"

  warn_msg "[NOTE] Please push ~/K8s-OIDC-Provider/ to GitHub Pages before running [5] External Secrets Operator, [6] Tailscale Operator, [7] Cloudflare Tunnel, [9] JuiceFS CSI Driver, [11] Qdrant Vector DB, [12] Argo CD GitOps, [13] Falco Security, [14] Grafana / Prometheus, [16] llama.cpp ROCm, [17] LiteLLM Gateway, [18] Open-WebUI."
  echo "=== [3 Installation Finished Successfully] ==="
}

do_test() {
  command -v kubectl >/dev/null 2>&1 || fail_exit "[FAIL] kubectl is not installed."
  [ -r "$HOME/.kube/config" ] || fail_exit "[FAIL] $HOME/.kube/config not found or not readable."

  local node_line node_name node_status k3s_ver
  node_line="$(kubectl get nodes --no-headers 2>/dev/null | head -n 1 || true)"
  node_name="$(echo "$node_line" | awk '{print $1}')"
  node_status="$(echo "$node_line" | awk '{print $2}')"
  k3s_ver="$(echo "$node_line" | awk '{print $5}')"

  if [ "$node_status" = "Ready" ]; then
    echo "[OK] Node $node_name is $node_status ($k3s_ver)"
  else
    fail_exit "[FAIL] Kubernetes node is not ready: ${node_status:-Unknown}"
  fi

  local total_pods non_running
  total_pods="$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  non_running="$(kubectl get pods -n kube-system --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$total_pods" -gt 0 ] && [ "$non_running" -eq 0 ]; then
    echo "[OK] All $total_pods core kube-system pods are Running/Completed"
  else
    fail_exit "[FAIL] kube-system pods check failed (total: $total_pods, non-running: $non_running)"
  fi

  if [ -f "/etc/rancher/k3s/config.yaml" ]; then
    echo "[OK] /etc/rancher/k3s/config.yaml is present"
  else
    warn_msg "[WARN] /etc/rancher/k3s/config.yaml not found"
  fi

  local issuer
  issuer="$(kubectl get --raw /.well-known/openid-configuration 2>/dev/null | grep -o '"issuer":"[^"]*"' || true)"
  if [ -n "$issuer" ]; then
    echo "[OK] OIDC Issuer configured: $issuer"
  else
    warn_msg "[WARN] Could not read OIDC Issuer from API server"
  fi

  if [ -s "$HOME/K8s-OIDC-Provider/.well-known/openid-configuration" ] && [ -s "$HOME/K8s-OIDC-Provider/jwks.json" ]; then
    echo "[OK] OIDC metadata files exported in ~/K8s-OIDC-Provider/"
  else
    fail_exit "[FAIL] OIDC metadata files missing or empty in ~/K8s-OIDC-Provider/"
  fi

  echo "=== [3 Verification Completed Successfully] ==="
}

do_restart() {
  install_k3s_config

  echo "Restarting K3s service..."
  sudo systemctl restart k3s 2>/dev/null || sudo service k3s restart 2>/dev/null || fail_exit "[FAIL] Failed to restart K3s service."

  sync_kubeconfig
  wait_for_k3s_api

  echo "=== [3 Restart Completed Successfully] ==="
}

do_uninstall() {
  echo "Uninstalling K3s cluster..."
  if [ -x "/usr/local/bin/k3s-uninstall.sh" ]; then
    sudo /usr/local/bin/k3s-uninstall.sh
  else
    echo "[INFO] /usr/local/bin/k3s-uninstall.sh not found, skipping."
  fi
  rm -f "$HOME/.kube/config"
  sudo rm -f /etc/rancher/k3s/config.yaml
  echo "=== [3 Uninstallation Completed Successfully] ==="
}

case "${1:-}" in
  -install)   do_install ;;
  -test)      do_test ;;
  -restart)   do_restart ;;
  -uninstall) do_uninstall ;;
  *)
    echo "Usage: $0 {-install|-test|-restart|-uninstall}"
    exit 1
    ;;
esac
