#!/usr/bin/env bash
# =====================================================================
#  [4] Helm 3 Package Manager
#  Helm CLI & Official Community Chart Repositories
#
#  Usage: ./04-Helm.sh {-install|-test|-restart|-uninstall}
# =====================================================================
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

fail_exit() { echo -e "$1"; exit 1; }

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

do_restart() {
  local DIR="$HOME/04-Helm"
  [ ! -d "$DIR" ] && DIR="$HOME/4-Helm"

  if [ -f "$DIR/init-helm-repos.sh" ]; then
    echo "Re-initializing Helm repositories..."
    bash "$DIR/init-helm-repos.sh"
  fi
  if command -v helm >/dev/null 2>&1; then
    echo "Updating Helm repositories..."
    helm repo update || true
  fi
  echo "=== [4 Restart/Refresh Completed Successfully] ==="
}

do_uninstall() {
  echo "Removing Helm 3 binary and cache..."
  sudo rm -f /usr/local/bin/helm
  rm -rf "$HOME/.config/helm" "$HOME/.cache/helm"
  echo "=== [4 Uninstallation Completed Successfully] ==="
}

case "$1" in
  -install)   do_install ;;
  -test)      do_test ;;
  -restart)   do_restart ;;
  -uninstall) do_uninstall ;;
  *)
    echo "Usage: $0 {-install|-test|-restart|-uninstall}"
    exit 1
    ;;
esac
