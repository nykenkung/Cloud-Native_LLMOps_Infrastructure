#!/usr/bin/env bash
# =====================================================================
#  [1] Hardware & OS Configuration
#  WSL2 Ubuntu 24.04, /etc/wsl.conf, ~/.bashrc & Base Utilities
#
#  Simple Installation Command:
#    sudo cp ~/1-Hardware-OS-Configuration/wsl.conf /etc/wsl.conf
#    cp ~/1-Hardware-OS-Configuration/.bashrc ~/.bashrc
#    sudo apt-get update -y && sudo apt-get install -y curl wget jq git ca-certificates gnupg openssh-server
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
  local DIR="$HOME/01-Hardware-OS-Configuration"
  [ ! -d "$DIR" ] && DIR="$HOME/1-Hardware-OS-Configuration"

  echo "--- Installing /etc/wsl.conf ---"
  if [ -f "$DIR/wsl.conf" ]; then
    sudo cp "$DIR/wsl.conf" /etc/wsl.conf
    sudo chmod 644 /etc/wsl.conf
    echo "[OK] /etc/wsl.conf installed"
  fi
  if [ -f "$DIR/.bashrc" ]; then
    echo "--- Installing ~/.bashrc ---"
    cp "$DIR/.bashrc" "$HOME/.bashrc"
    echo "[OK] ~/.bashrc installed"
  fi
  echo "--- Installing base utilities ---"
  sudo apt-get update -y
  sudo apt-get install -y curl wget jq git ca-certificates gnupg openssh-server
  echo "--- Configuring system sysctl limits (inotify limits for eBPF / K8s) ---"
  sudo sysctl -w fs.inotify.max_user_instances=8192 >/dev/null 2>&1 || true
  sudo sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null 2>&1 || true
  echo "fs.inotify.max_user_instances=8192" | sudo tee /etc/sysctl.d/99-inotify.conf >/dev/null
  echo "fs.inotify.max_user_watches=1048576" | sudo tee -a /etc/sysctl.d/99-inotify.conf >/dev/null
  echo "=== [1 Installation Finished Successfully] ==="
}

do_test() {
  if [ -f "/etc/wsl.conf" ]; then
    echo "[OK] /etc/wsl.conf exists"
    if grep -q "mount --make-rshared" /etc/wsl.conf; then
      echo "[OK] /etc/wsl.conf contains rshared mount command"
    else
      fail_exit "[FAIL] /etc/wsl.conf missing rshared mount command"
    fi
  else
    fail_exit "[FAIL] /etc/wsl.conf not found"
  fi
  if grep -q "KUBECONFIG" "$HOME/.bashrc"; then
    echo "[OK] ~/.bashrc contains KUBECONFIG"
  else
    fail_exit "[FAIL] ~/.bashrc missing KUBECONFIG"
  fi
  for cmd in curl wget jq git ssh; do
    if command -v $cmd >/dev/null 2>&1; then
      echo "[OK] Command $cmd is available"
    else
      fail_exit "[FAIL] Command $cmd not found"
    fi
  done
  echo "=== [1 Verification Completed Successfully] ==="
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
