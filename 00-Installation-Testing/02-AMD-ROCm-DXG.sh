#!/usr/bin/env bash
# ================================================================================
#  [2] AMD ROCm & DXG Hardware Virtualization
#  Radeon 8060S /dev/dxg, librocdxg.so & Diagnostic Pod
#
#  Usage: ./02-AMD-ROCm-DXG.sh {-install|-test|-restart|-uninstall}
# ================================================================================
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
  local DIR="$HOME/02-AMD-ROCm-DXG"
  [ ! -d "$DIR" ] && DIR="$HOME/2-AMD-ROCm-DXG"

  if [ ! -e "/dev/dxg" ]; then
    echo "[WARNING] /dev/dxg not detected! Ensure WSL2 DXG virtualization is enabled."
  fi
  if ! command -v rocminfo >/dev/null 2>&1; then
    echo "Installing ROCm core packages from Radeon repository..."
    sudo mkdir -p --mode=0755 /etc/apt/keyrings
    wget -qO- https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg >/dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/latest noble main" | sudo tee /etc/apt/sources.list.d/rocm.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y rocm-core hsa-rocr rocminfo
  fi
  if ls "$DIR/"*rocdxg*.deb 1>/dev/null 2>&1; then
    echo "Installing librocdxg package from $DIR..."
    sudo dpkg -i "$DIR/"*rocdxg*.deb || sudo apt-get install -f -y
  elif [ ! -e "/opt/rocm/lib/librocdxg.so" ] && [ ! -e "/usr/lib/librocdxg.so" ]; then
    echo "Downloading and installing librocdxg v1.2.2..."
    local tmp_deb="/tmp/rocdxg-roct_1.2.2_amd64.deb"
    wget -qO "$tmp_deb" https://github.com/ROCm/librocdxg/releases/download/v1.2.2/rocdxg-roct_1.2.2_amd64.deb
    sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
    rm -f "$tmp_deb"
  fi
  sudo mkdir -p /opt/rocm/lib
  if [ -e "/usr/lib/librocdxg.so" ] && [ ! -e "/opt/rocm/lib/librocdxg.so" ]; then
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

do_restart() {
  local DIR="$HOME/02-AMD-ROCm-DXG"
  [ ! -d "$DIR" ] && DIR="$HOME/2-AMD-ROCm-DXG"

  if command -v kubectl >/dev/null 2>&1; then
    echo "Re-applying AMD ROCm Diagnostic Pod manifests..."
    [ -d "$DIR" ] && kubectl apply -f "$DIR" || true
    kubectl rollout restart deploy -n amd-rocdxg 2>/dev/null || true
  fi
  echo "=== [2 Restart/Rollover Completed Successfully] ==="
}

do_uninstall() {
  local DIR="$HOME/02-AMD-ROCm-DXG"
  [ ! -d "$DIR" ] && DIR="$HOME/2-AMD-ROCm-DXG"

  if command -v kubectl >/dev/null 2>&1; then
    [ -d "$DIR" ] && kubectl delete -f "$DIR" --ignore-not-found 2>/dev/null || true
    kubectl delete ns amd-rocdxg --ignore-not-found 2>/dev/null || true
  fi
  echo -e "[NOTE] Host ROCm packages & /dev/dxg preserved for system stability."
  echo "=== [2 Uninstallation Completed Successfully] ==="
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