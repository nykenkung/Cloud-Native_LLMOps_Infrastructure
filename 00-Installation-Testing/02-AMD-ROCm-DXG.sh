#!/usr/bin/env bash
# =====================================================================
#  [2] AMD ROCm & DXG Hardware Virtualization
#  Radeon 8060S /dev/dxg, librocdxg.so & Diagnostic Pod
#
#  Simple Installation Command:
#    sudo dpkg -i ~/2-AMD-ROCm-DXG/*rocdxg*.deb
#    sudo ln -sf /usr/lib/librocdxg.so /opt/rocm/lib/librocdxg.so
#    kubectl apply -f ~/2-AMD-ROCm-DXG
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
  local DIR="$HOME/02-AMD-ROCm-DXG"
  [ ! -d "$DIR" ] && DIR="$HOME/2-AMD-ROCm-DXG"

  if [ ! -e "/dev/dxg" ]; then
    echo "[WARNING] /dev/dxg not detected! Ensure WSL2 DXG virtualization is enabled."
  fi
  if ls "$DIR/"*rocdxg*.deb 1>/dev/null 2>&1; then
    echo "Installing librocdxg package..."
    sudo dpkg -i "$DIR/"*rocdxg*.deb || sudo apt-get install -f -y
  fi
  sudo mkdir -p /opt/rocm/lib
  if [ -f "/usr/lib/librocdxg.so" ]; then
    sudo ln -sf /usr/lib/librocdxg.so /opt/rocm/lib/librocdxg.so
  fi
  if command -v kubectl >/dev/null 2>&1; then
    echo "Deploying AMD ROCm Diagnostic Pod..."
    kubectl apply -f "$DIR" || true
  fi
  echo "=== [2 Installation Finished Successfully] ==="
}

do_test() {
  if [ -e "/dev/dxg" ]; then
    echo "[OK] Device /dev/dxg exists"
  else
    fail_exit "[FAIL] Device /dev/dxg not found"
  fi
  if [ -f "/opt/rocm/lib/librocdxg.so" ] || [ -f "/usr/lib/librocdxg.so" ]; then
    echo "[OK] librocdxg.so exists"
  else
    fail_exit "[FAIL] librocdxg.so not found"
  fi
  if kubectl get pod -n amd-rocdxg -l app=amd-rocdxg-pod --no-headers 2>/dev/null | grep -q "Running"; then
    echo "Testing PyTorch GPU detection in amd-rocdxg pod..."
    ROCM_CHECK=$(kubectl exec -n amd-rocdxg deployment/amd-rocdxg-deploy -- env LD_LIBRARY_PATH="/usr/local/lib/python3.12/dist-packages/_rocm_sdk_core/lib:/usr/local/lib/python3.12/dist-packages/_rocm_sdk_devel/lib:/usr/lib/wsl/lib:/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH" python3 -c \
      "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')" 2>/dev/null || echo "False None")
    if echo "$ROCM_CHECK" | grep -q "True"; then
      echo "[OK] PyTorch ROCm GPU Detection: $ROCM_CHECK"
    else
      fail_exit "[FAIL] PyTorch ROCm GPU Detection Failed: $ROCM_CHECK"
    fi
  else
    fail_exit "[FAIL] amd-rocdxg pod is not Running"
  fi
  echo "=== [2 Verification Completed Successfully] ==="
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
