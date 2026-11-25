#!/usr/bin/env bash
# =====================================================================
#  [3] Kubernetes (K3s) Cluster
#  Lightweight K3s, kubeconfig & ~/.bashrc Integration
#
#  Simple Installation Command:
#    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
#    mkdir -p ~/.kube && sudo install -m 600 -o $USER /etc/rancher/k3s/k3s.yaml ~/.kube/config
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

do_install() {
  local DIR="$HOME/03-Kubernetes"
  [ ! -d "$DIR" ] && DIR="$HOME/3-Kubernetes"

  if [ -f "$DIR/config.yaml" ]; then
    echo "Installing /etc/rancher/k3s/config.yaml..."
    sudo mkdir -p /etc/rancher/k3s
    sudo cp "$DIR/config.yaml" /etc/rancher/k3s/config.yaml
  fi

  if ! command -v k3s >/dev/null 2>&1; then
    echo "Installing K3s (without Traefik)..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
  else
    echo "K3s is already installed."
  fi
  mkdir -p "$HOME/.kube"
  if sudo test -f "/etc/rancher/k3s/k3s.yaml"; then
    echo "Installing ~/.kube/config from /etc/rancher/k3s/k3s.yaml..."
    sudo install -m 600 -o "$(id -u)" -g "$(id -g)" /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  else
    fail_exit "[FAIL] /etc/rancher/k3s/k3s.yaml not found after K3s installation."
  fi
  export KUBECONFIG="$HOME/.kube/config"
  if ! grep -q "KUBECONFIG" "$HOME/.bashrc"; then
    echo 'export KUBECONFIG=$HOME/.kube/config' >> "$HOME/.bashrc"
  fi
  echo "Exporting K3s OIDC metadata (openid-configuration & jwks.json)..."
  mkdir -p "$HOME/K8s-OIDC-Provider/.well-known"
  kubectl get --raw /.well-known/openid-configuration > "$HOME/K8s-OIDC-Provider/.well-known/openid-configuration"
  kubectl get --raw /openid/v1/jwks > "$HOME/K8s-OIDC-Provider/jwks.json"
  echo -e "\033[1;33m[NOTE] Please push ~/K8s-OIDC-Provider/ to GitHub Pages before running [5] External Secrets Operator, [6] Tailscale Operator, [7] Cloudflare Tunnel, [9] JuiceFS CSI Driver, [11] Qdrant Vector DB, [12] Argo CD GitOps, [13] Falco Security, [14] Grafana / Prometheus, [16] llama.cpp ROCm, [17] LiteLLM Gateway, [18] Open-WebUI.\033[0m"
  echo "=== [3 Installation Finished Successfully] ==="
}

do_test() {
  NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -n 1)
  if [ "$NODE_STATUS" = "Ready" ]; then
    NODE_NAME=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}' | head -n 1)
    K3S_VER=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $5}' | head -n 1)
    echo "[OK] Node $NODE_NAME is $NODE_STATUS ($K3S_VER)"
  else
    fail_exit "[FAIL] Kubernetes node is not ready: $NODE_STATUS"
  fi
  NON_RUNNING=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
  if [ "$NON_RUNNING" -eq 0 ]; then
    echo "[OK] All core kube-system pods are Running/Completed"
  else
    fail_exit "[FAIL] Found $NON_RUNNING non-running pods in kube-system"
  fi
  ISSUER=$(kubectl get --raw /.well-known/openid-configuration 2>/dev/null | grep -o '"issuer":"[^"]*"' || true)
  if [ -n "$ISSUER" ]; then
    echo "[OK] OIDC Issuer configured: $ISSUER"
  fi
  echo "=== [3 Verification Completed Successfully] ==="
}

case "$1" in
  -install|--install|install)
    do_install
    ;;
  -test|--test|test)
    do_test
    ;;
  *)
    echo "Usage: $0 {-install|-test}"
    exit 1
    ;;
esac
