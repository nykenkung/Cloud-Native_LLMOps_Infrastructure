#!/usr/bin/env bash
# =====================================================================
#  [1] Hardware & OS Configuration
#  WSL2 Ubuntu 24.04, /etc/wsl.conf, ~/.bashrc & Base Utilities
#
#  Usage: ./01-Hardware-OS-Configuration.sh {-install|-test|-restart|-uninstall}
# =====================================================================
set -e

fail_exit() { echo -e "$1"; exit 1; }

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
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "[OK] Command $cmd is available"
    else
      fail_exit "[FAIL] Command $cmd not found"
    fi
  done
  echo "=== [1 Verification Completed Successfully] ==="
}

do_restart() {
  local DIR="$HOME/01-Hardware-OS-Configuration"
  [ ! -d "$DIR" ] && DIR="$HOME/1-Hardware-OS-Configuration"

  echo "--- Re-applying /etc/wsl.conf & ~/.bashrc ---"
  if [ -f "$DIR/wsl.conf" ]; then
    sudo cp "$DIR/wsl.conf" /etc/wsl.conf
    sudo chmod 644 /etc/wsl.conf
  fi
  if [ -f "$DIR/.bashrc" ]; then
    cp "$DIR/.bashrc" "$HOME/.bashrc"
  fi
  echo "--- Reloading sysctl & restarting SSH service ---"
  sudo sysctl -w fs.inotify.max_user_instances=8192 >/dev/null 2>&1 || true
  sudo sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null 2>&1 || true
  sudo sysctl --system >/dev/null 2>&1 || true
  sudo systemctl restart ssh 2>/dev/null || sudo service ssh restart 2>/dev/null || true
  echo "=== [1 Restart/Re-apply Completed Successfully] ==="
}

do_uninstall() {
  echo "--- Cleaning up custom sysctl limits ---"
  sudo rm -f /etc/sysctl.d/99-inotify.conf
  sudo sysctl --system >/dev/null 2>&1 || true
  echo -e "[NOTE] Base OS packages (curl, jq, git, ssh), ~/.bashrc, and /etc/wsl.conf were preserved for WSL2 stability."
  echo "=== [1 Uninstallation Completed Successfully] ==="
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
