#!/usr/bin/env bash
# =====================================================================
#  [4] Helm 3 Package Manager
#  Helm CLI & Official Community Chart Repositories
#
#  Simple Installation Command:
#    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
#    bash ~/4-Helm/init-helm-repos.sh
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "\033[0;31m$1\033[0m"; exit 1; }

do_install() {
  if ! command -v helm >/dev/null 2>&1; then
    echo "Installing Helm 3..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  else
    echo "Helm 3 is already installed."
  fi
  local DIR="$HOME/04-Helm"
  [ ! -d "$DIR" ] && DIR="$HOME/4-Helm"

  if [ -f "$DIR/init-helm-repos.sh" ]; then
    echo "Initializing official Helm chart repositories..."
    chmod +x "$DIR/init-helm-repos.sh"
    bash "$DIR/init-helm-repos.sh"
  fi
  echo "=== [4 Installation Finished Successfully] ==="
}

do_test() {
  if command -v helm >/dev/null 2>&1; then
    HELM_VER=$(helm version --short 2>/dev/null)
    HELM_REPOS=$(helm repo list 2>/dev/null | tail -n +2 | wc -l)
    if [ "$HELM_REPOS" -gt 0 ]; then
      echo "[OK] Helm 3 ($HELM_VER) installed with $HELM_REPOS repositories configured"
    else
      fail_exit "[FAIL] Helm 3 installed but no repositories configured"
    fi
  else
    fail_exit "[FAIL] Helm 3 not found in PATH"
  fi
  echo "=== [4 Verification Completed Successfully] ==="
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
