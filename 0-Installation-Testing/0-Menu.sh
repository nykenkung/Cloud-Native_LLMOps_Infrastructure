#!/usr/bin/env bash

# Robust KUBECONFIG discovery
if [ -z "$KUBECONFIG" ]; then
  if [ -f "$HOME/.kube/config" ] && [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -f "/etc/rancher/k3s/k3s.yaml" ] && [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_script() {
  local num=$1
  case "$num" in
    1) echo "1-Hardware-OS-Configuration.sh" ;;
    2) echo "2-AMD-ROCm-DXG.sh" ;;
    3) echo "3-Kubernetes.sh" ;;
    4) echo "4-Helm.sh" ;;
    5) echo "5-External-Secrets-Operator.sh" ;;
    6) echo "6-Tailscale-Operator.sh" ;;
    7) echo "7-Cloudflare-Tunnel.sh" ;;
    8) echo "8-Ingress-Nginx.sh" ;;
    9) echo "9-JuiceFS-CSI-Driver.sh" ;;
    10) echo "10-CloudNativePG-DB.sh" ;;
    11) echo "11-Qdrant-Vector-DB.sh" ;;
    12) echo "12-ArgoCD-GitOps.sh" ;;
    13) echo "13-Falco-Security.sh" ;;
    14) echo "14-Grafana-Prometheus-Stack.sh" ;;
    15) echo "15-KEDA-Autoscaler.sh" ;;
    16) echo "16-LLaMAcpp-ROCm.sh" ;;
    17) echo "17-LiteLLM-Gateway.sh" ;;
    18) echo "18-Open-WebUI.sh" ;;
    *) echo "" ;;
  esac
}

run_step() {
  local num=$1
  local mode=$2 # -install or -test
  local script
  script=$(get_script "$num")
  echo ""
  if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script" "$mode" || echo -e "\n\033[0;31m[FAILED] []$num ($script $mode) returned an error.\033[0m"
  else
    echo -e "\033[0;31m[ERROR] Script not found for step $num\033[0m"
  fi
}

run_install_all() {
  echo ""
  echo "=================================================================="
  echo " Running Full Installation Pipeline (Steps 1 -> 18)"
  echo "=================================================================="
  for i in $(seq 1 18); do
    echo ""
    echo ">>> [INSTALL Step $i/18] Running $(get_script $i)..."
    local script
    script=$(get_script "$i")
    if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
      if ! bash "$SCRIPT_DIR/$script" "-install"; then
        echo -e "\n\033[0;31m[ABORT] Installation failed at []$i ($(get_script $i)).\033[0m"
        return 1
      fi
    fi
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Installation Pipeline Completed Successfully!"
  echo "=================================================================="
}

run_test_all() {
  echo ""
  echo "=================================================================="
  echo " Running Full Verification Pipeline (Steps 1 -> 18)"
  echo "=================================================================="
  for i in $(seq 1 18); do
    echo ""
    echo ">>> [TEST Step $i/18] Running $(get_script $i)..."
    local script
    script=$(get_script "$i")
    if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
      if ! bash "$SCRIPT_DIR/$script" "-test"; then
        echo -e "\n\033[0;31m[ABORT] Verification failed at []$i ($(get_script $i)).\033[0m"
        return 1
      fi
    fi
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Verification Pipeline Completed Successfully!"
  echo "=================================================================="
}

run_benchmark() {
  local num=$1
  local script=""
  case "$num" in
    100) script="100-Download-LLM.sh" ;;
    101) script="101-Test-AI-Stack-E2E.sh" ;;
    102) script="102-Test-Security-Penetration.sh" ;;
    103) script="103-Test-RAG-Benchmark.sh" ;;
    104) script="104-Test-Concurrency-Throughput.sh" ;;
    105) script="105-Test-Context-Stress.sh" ;;
    106) script="106-Test-Needle-In-Haystack.sh" ;;
    107) script="107-Test-LLM-Guardrails-OWASP.sh" ;;
    108) script="108-Test-Cluster-Security-Audit.sh" ;;
    109) script="109-Test-Storage-Persistence-Failover.sh" ;;
    110) script="110-Test-LLM-CLI.sh" ;;
  esac

  echo ""
  if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script" || echo -e "\n\033[0;31m[FAILED] $script returned an error.\033[0m"
  else
    echo -e "\033[0;31m[ERROR] Script not found: $script\033[0m"
  fi
}

# Map letter to step number:
# B/b -> 1, C/c -> 2, D/d -> 3, E/e -> 4, F/f -> 5, G/g -> 6, H/h -> 7, I/i -> 8, J/j -> 9
# K/k -> 10, L/l -> 11, M/m -> 12, N/n -> 13, O/o -> 14, P/p -> 15, Q/q -> 16, R/r -> 17, S/s -> 18
run_letter_test() {
  local char
  char=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  case "$char" in
    A) run_test_all ;;
    B) run_step 1 "-test" ;;
    C) run_step 2 "-test" ;;
    D) run_step 3 "-test" ;;
    E) run_step 4 "-test" ;;
    F) run_step 5 "-test" ;;
    G) run_step 6 "-test" ;;
    H) run_step 7 "-test" ;;
    I) run_step 8 "-test" ;;
    J) run_step 9 "-test" ;;
    K) run_step 10 "-test" ;;
    L) run_step 11 "-test" ;;
    M) run_step 12 "-test" ;;
    N) run_step 13 "-test" ;;
    O) run_step 14 "-test" ;;
    P) run_step 15 "-test" ;;
    Q) run_step 16 "-test" ;;
    R) run_step 17 "-test" ;;
    S) run_step 18 "-test" ;;
    *) echo -e "\n\033[0;31m[ERROR] Unknown test option: $1\033[0m" ;;
  esac
}

show_menu() {
  echo ""
  printf "%-45s%s\n" " [0] Install / [A] Test ALL"                  "[12] Install / [M] Test ArgoCD-GitOps"
  printf "%-45s%s\n" " [1] Install / [B] Test Hardware-OS-Config"   "[13] Install / [N] Test Falco-Security"
  printf "%-45s%s\n" " [2] Install / [C] Test AMD-ROCm-DXG"         "[14] Install / [O] Test Grafana-Prometheus"
  printf "%-45s%s\n" " [3] Install / [D] Test Kubernetes"           "[15] Install / [P] Test KEDA-Autoscaler"
  printf "%-45s%s\n" " [4] Install / [E] Test Helm"                 "[16] Install / [Q] Test LLaMAcpp-ROCm"
  printf "%-45s%s\n" " [5] Install / [F] Test External-Secrets"     "[17] Install / [R] Test LiteLLM-Gateway"
  printf "%-45s%s\n" " [6] Install / [G] Test Tailscale-Operator"   "[18] Install / [S] Test Open-WebUI"
  echo " [7] Install / [H] Test Cloudflare-Tunnel"
  echo " [8] Install / [I] Test Ingress-Nginx"
  echo " [9] Install / [J] Test JuiceFS-CSI"
  echo "[10] Install / [K] Test CloudNativePG-DB"
  echo "[11] Install / [L] Test Qdrant-Vector-DB"
  echo "-----------------------------------------------------------------------------------------"
  echo "[100] Download-LLM                      - High-Speed LLM Model Download"
  echo "[101] Test AI-Stack-E2E                 - End-to-End Stack Pipeline Verification"
  echo "[102] Test Security-Penetration         - Security Pen-Test, NetworkPolicy & Falco Audit"
  echo "[103] Test RAG-Benchmark                - Qdrant Vector Search & Closed-Loop RAG QA"
  echo "[104] Test Concurrency-Throughput       - Multi-User Concurrency, TPS & TTFT Latency"
  echo "[105] Test Context-Stress               - Stepped Context (1K~32K) & ROCm VRAM Test"
  echo "[106] Test Needle-In-Haystack           - 32K Needle-In-A-Haystack (NIAH) Memory Test"
  echo "[107] Test LLM-Guardrails-OWASP         - LLM Guardrails & OWASP Top 10 Security Audit"
  echo "[108] Test Cluster-Security-Audit       - K8s RBAC, Pod Security & Secret Isolation Audit"
  echo "[109] Test Storage-Persistence-Failover - Storage CSI, Data Persistence & Self-Healing"
  echo "[110] Test LLM-CLI                      - Interactive LLM Model Selection & CLI Chat"
  echo ""
  echo -n "Please select an option (Ctrl+C to Quit): "
}

# Handle CLI arguments if provided
if [ "$#" -ge 1 ]; then
  case "$1" in
    0|"install-all"|"ia") run_install_all; exit 0 ;;
    [1-9]|1[0-8])
      MODE="${2:--install}"
      run_step "$1" "$MODE"
      exit 0
      ;;
    "a"|"A"|"test-all"|"ta") run_test_all; exit 0 ;;
    [b-sB-S]) run_letter_test "$1"; exit 0 ;;
    10[0-9]|110) run_benchmark "$1"; exit 0 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
fi

# Interactive Menu Loop (Always returns to menu on success or error; exit via Ctrl+C)
while true; do
  show_menu
  read -r choice || { echo ""; exit 0; }
  case "$choice" in
    0) run_install_all ;;
    [1-9]|1[0-8]) run_step "$choice" "-install" ;;
    [a-sA-S]) run_letter_test "$choice" ;;
    10[0-9]|110) run_benchmark "$choice" ;;
    "") ;;
    *) echo -e "\n\033[0;33mInvalid option '$choice'. Please try again.\033[0m" ;;
  esac
done
