#!/usr/bin/env bash

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_script() {
  local num=$1
  case "$num" in
    1)  [ -f "$SCRIPT_DIR/01-Hardware-OS-Configuration.sh" ] && echo "01-Hardware-OS-Configuration.sh" || echo "1-Hardware-OS-Configuration.sh" ;;
    2)  [ -f "$SCRIPT_DIR/02-AMD-ROCm-DXG.sh" ] && echo "02-AMD-ROCm-DXG.sh" || echo "2-AMD-ROCm-DXG.sh" ;;
    3)  [ -f "$SCRIPT_DIR/03-Kubernetes.sh" ] && echo "03-Kubernetes.sh" || echo "3-Kubernetes.sh" ;;
    4)  [ -f "$SCRIPT_DIR/04-Helm.sh" ] && echo "04-Helm.sh" || echo "4-Helm.sh" ;;
    5)  [ -f "$SCRIPT_DIR/05-External-Secrets-Operator.sh" ] && echo "05-External-Secrets-Operator.sh" || echo "5-External-Secrets-Operator.sh" ;;
    6)  [ -f "$SCRIPT_DIR/06-Tailscale-Operator.sh" ] && echo "06-Tailscale-Operator.sh" || echo "6-Tailscale-Operator.sh" ;;
    7)  [ -f "$SCRIPT_DIR/07-Cloudflare-Tunnel.sh" ] && echo "07-Cloudflare-Tunnel.sh" || echo "7-Cloudflare-Tunnel.sh" ;;
    8)  [ -f "$SCRIPT_DIR/08-Ingress-Nginx.sh" ] && echo "08-Ingress-Nginx.sh" || echo "8-Ingress-Nginx.sh" ;;
    9)  [ -f "$SCRIPT_DIR/09-JuiceFS-CSI-Driver.sh" ] && echo "09-JuiceFS-CSI-Driver.sh" || echo "9-JuiceFS-CSI-Driver.sh" ;;
    10) echo "10-CloudNativePG-DB.sh" ;;
    11) echo "11-Qdrant-Vector-DB.sh" ;;
    12) echo "12-ArgoCD-GitOps.sh" ;;
    13) echo "13-Falco-Security.sh" ;;
    14) echo "14-Grafana-Prometheus-Stack.sh" ;;
    15) echo "15-KEDA-Autoscaler.sh" ;;
    16) echo "16-LLaMAcpp-ROCm.sh" ;;
    17) echo "17-LiteLLM-Gateway.sh" ;;
    18) echo "18-Open-WebUI.sh" ;;
    *)  echo "" ;;
  esac
}

run_step() {
  local num=$1
  local mode=$2 # -install, -test, -restart, or -uninstall
  local script
  script=$(get_script "$num")
  echo ""
  if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
    if ! bash "$SCRIPT_DIR/$script" "$mode"; then
      echo -e "\n[FAILED] Step $num ($script $mode) returned an error."
      return 1
    fi
  else
    echo -e "[ERROR] Script not found for step $num"
    return 1
  fi
  return 0
}

run_install_all() {
  echo ""
  echo "=================================================================="
  echo " Running Full Installation Pipeline (Steps 1 -> 18)"
  echo "=================================================================="
  for i in $(seq 1 18); do
    echo ""
    echo ">>> [INSTALL Step $i/18] Running $(get_script "$i")..."
    if ! run_step "$i" "-install"; then
      echo -e "\n[ABORT] Installation failed at Step $i ($(get_script "$i"))."
      return 1
    fi
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Installation Pipeline Completed Successfully!"
  echo "=================================================================="
  return 0
}

run_test_all() {
  echo ""
  echo "=================================================================="
  echo " Running Full Verification Pipeline (Steps 1 -> 18)"
  echo "=================================================================="
  for i in $(seq 1 18); do
    echo ""
    echo ">>> [TEST Step $i/18] Running $(get_script "$i")..."
    if ! run_step "$i" "-test"; then
      echo -e "\n[ABORT] Verification failed at Step $i ($(get_script "$i"))."
      return 1
    fi
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Verification Pipeline Completed Successfully!"
  echo "=================================================================="
  return 0
}

run_restart_all() {
  echo ""
  echo "=================================================================="
  echo " Running Full Re-apply & Rollover Pipeline (Steps 1 -> 18)"
  echo "=================================================================="
  for i in $(seq 1 18); do
    echo ""
    echo ">>> [RESTART Step $i/18] Running $(get_script "$i")..."
    if ! run_step "$i" "-restart"; then
      echo -e "\n[ABORT] Restart failed at Step $i ($(get_script "$i"))."
      return 1
    fi
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Re-apply & Rollover Pipeline Completed Successfully!"
  echo "=================================================================="
  return 0
}

run_uninstall_all() {
  echo ""
  echo -e "[WARNING] This will UNINSTALL Steps 18 down to 1 (including all K8s apps, Helm releases, and K3s cluster)!"
  echo -n "Type 'yes' to confirm full removal: "
  read -r confirm
  echo ""
  if [ "$confirm" != "yes" ]; then
    echo "Uninstallation cancelled."
    return 0
  fi

  echo "=================================================================="
  echo " Running Full Uninstallation Pipeline (Steps 18 -> 1)"
  echo "=================================================================="
  for i in $(seq 18 -1 1); do
    echo ""
    echo ">>> [UNINSTALL Step $i/18] Running $(get_script "$i")..."
    run_step "$i" "-uninstall" || echo -e "[WARN] Step $i uninstall returned non-zero, continuing..."
  done
  echo ""
  echo "=================================================================="
  echo " [OK] Full Uninstallation Pipeline (Steps 18 -> 1) Completed!"
  echo "=================================================================="
  return 0
}

run_utility() {
  local num=$1
  local script=""
  case "$num" in
    91) script="91-Check-Pod-Status.sh" ;;
    92) script="92-Reveal-ESO-Secrets.sh" ;;
  esac

  echo ""
  if [ -n "$script" ] && [ -f "$SCRIPT_DIR/$script" ]; then
    if ! bash "$SCRIPT_DIR/$script"; then
      echo -e "\n[FAILED] $script returned an error."
      return 1
    fi
  else
    echo -e "[ERROR] Script not found: $script"
    return 1
  fi
  return 0
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
    if ! bash "$SCRIPT_DIR/$script"; then
      echo -e "\n[FAILED] $script returned an error."
      return 1
    fi
  else
    echo -e "[ERROR] Script not found: $script"
    return 1
  fi
  return 0
}

# Map letter action:
# A/a -> ALL, B/b -> 1 ... S/s -> 18
# Suffix: "" -> -test, "+" -> -restart, "-" -> -uninstall
run_letter_action() {
  local token
  token=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  local letter="${token:0:1}"
  local suffix="${token:1:1}"

  local mode="-test"
  case "$suffix" in
    "")  mode="-test" ;;
    "+") mode="-restart" ;;
    "-") mode="-uninstall" ;;
    *)   return 1 ;;
  esac

  if [ "$letter" = "A" ]; then
    case "$mode" in
      -test)      run_test_all ;;
      -restart)   run_restart_all ;;
      -uninstall) run_uninstall_all ;;
    esac
    return $?
  fi

  local step=""
  case "$letter" in
    B) step=1 ;;  C) step=2 ;;  D) step=3 ;;  E) step=4 ;;  F) step=5 ;;
    G) step=6 ;;  H) step=7 ;;  I) step=8 ;;  J) step=9 ;;  K) step=10 ;;
    L) step=11 ;; M) step=12 ;; N) step=13 ;; O) step=14 ;; P) step=15 ;;
    Q) step=16 ;; R) step=17 ;; S) step=18 ;;
    *) return 1 ;;
  esac

  run_step "$step" "$mode"
}

# Validate if a single token is strictly within:
# 0-18, a-s/A-S, a+-s+/A+-S+, a--s-/A--S-, 91-92, 100-110
is_valid_task() {
  case "$1" in
    0|[1-9]|1[0-8]|[a-sA-S]|[a-sA-S]+|[a-sA-S]-|91|92|10[0-9]|110) return 0 ;;
    *) return 1 ;;
  esac
}

# Execute a single validated task
execute_single_task() {
  local task=$1
  case "$task" in
    0) run_install_all ;;
    [1-9]|1[0-8]) run_step "$task" "-install" ;;
    [a-sA-S]|[a-sA-S]+|[a-sA-S]-) run_letter_action "$task" ;;
    91|92) run_utility "$task" ;;
    10[0-9]|110) run_benchmark "$task" ;;
  esac
}

# Validate and run a sequence of tasks sequentially (stops on first failure)
run_task_queue() {
  local tasks=("$@")

  for t in "${tasks[@]}"; do
    if ! is_valid_task "$t"; then
      echo -e "\n[ERROR] Invalid option '$t'. Allowed: 0-18, A-S, A+-S+, A--S-, 91-92, 100-110."
      return 1
    fi
  done

  local total=${#tasks[@]}
  local idx=1
  for t in "${tasks[@]}"; do
    if [ "$total" -gt 1 ]; then
      echo -e "\n>>> [Queue $idx/$total] Executing task: '$t'"
    fi
    if ! execute_single_task "$t"; then
      if [ "$total" -gt 1 ]; then
        echo -e "\n[QUEUE ABORTED] Stopped at task '$t' ($idx/$total) due to failure."
      fi
      return 1
    fi
    ((idx++))
  done
  return 0
}

show_menu() {
  echo ""
  echo " [0] Install ALL               ,[A] Run Test, [A+] Restart, [A-] Uninstall (ALL)"
  echo " [1] Install Hardware-OS-Config,[B] Run Test, [B+] Restart, [B-] Uninstall (1)"
  echo " [2] Install AMD-ROCm-DXG      ,[C] Run Test, [C+] Restart, [C-] Uninstall (2)"
  echo " [3] Install Kubernetes        ,[D] Run Test, [D+] Restart, [D-] Uninstall (3)"
  echo " [4] Install Helm              ,[E] Run Test, [E+] Restart, [E-] Uninstall (4)"
  echo " [5] Install External-Secrets  ,[F] Run Test, [F+] Restart, [F-] Uninstall (5)"
  echo " [6] Install Tailscale-Operator,[G] Run Test, [G+] Restart, [G-] Uninstall (6)"
  echo " [7] Install Cloudflare-Tunnel ,[H] Run Test, [H+] Restart, [H-] Uninstall (7)"
  echo " [8] Install Ingress-Nginx     ,[I] Run Test, [I+] Restart, [I-] Uninstall (8)"
  echo " [9] Install JuiceFS-CSI       ,[J] Run Test, [J+] Restart, [J-] Uninstall (9)"
  echo "[10] Install CloudNativePG-DB  ,[K] Run Test, [K+] Restart, [K-] Uninstall (10)"
  echo "[11] Install Qdrant-Vector-DB  ,[L] Run Test, [L+] Restart, [L-] Uninstall (11)"
  echo "[12] Install ArgoCD-GitOps     ,[M] Run Test, [M+] Restart, [M-] Uninstall (12)"
  echo "[13] Install Falco-Security    ,[N] Run Test, [N+] Restart, [N-] Uninstall (13)"
  echo "[14] Install Grafana-Prometheus,[O] Run Test, [O+] Restart, [O-] Uninstall (14)"
  echo "[15] Install KEDA-Autoscaler   ,[P] Run Test, [P+] Restart, [P-] Uninstall (15)"
  echo "[16] Install LLaMAcpp-ROCm     ,[Q] Run Test, [Q+] Restart, [Q-] Uninstall (16)"
  echo "[17] Install LiteLLM-Gateway   ,[R] Run Test, [R+] Restart, [R-] Uninstall (17)"
  echo "[18] Install Open-WebUI        ,[S] Run Test, [S+] Restart, [S-] Uninstall (18)"
  echo ""
  echo "[91] Check Cluster Deployment      [92] Export ESO Secrets (GCP JSON)"
  echo "--------------------------------------------------------------------------------"
  echo "[100] Download LLM: High-speed download HuggingFace LLM models to /HuggingFace-Models"
  echo "[101] Test AI Stack E2E: End-to-end AI inference, full stack pipeline verification"
  echo "[102] Test Security Penetration: NetworkPolicy, pen-test, Falco runtime audit"
  echo "[103] Test RAG Benchmark (Retrieval): Qdrant vector search, closed-loop QA evaluation"
  echo "[104] Test Concurrency Throughput: Multi-user concurrency, TPS, TTFT latency test"
  echo "[105] Test Context Stress: Stepped context window (1K~32K), memory pressure test"
  echo "[106] Test Needle In Haystack: 32K long-context precision retrieval verification"
  echo "[107] Test LLM Guardrails OWASP (Safety): Prompt injection defense, OWASP Top 10 audit"
  echo "[108] Test Cluster Security: Kubernetes permissions, Pod Security, Secret isolation"
  echo "[109] Test Storage Persistence Failover: CSI volume durability, pod self-healing"
  echo "[110] Test LLM CLI (Interactive): Interactive LLM model selection, terminal chat"
  echo ""
  echo -n "Select one or more options (Example: 91 101 110) [Ctrl+C to Quit]: "
}

# Handle CLI arguments (Strictly 0-18, A-S, A+-S+, A--S-, 91-92, 100-110; supports multiple sequential tasks)
if [ "$#" -ge 1 ]; then
  if run_task_queue "$@"; then
    exit 0
  else
    exit 1
  fi
fi

# Interactive Menu Loop
while true; do
  show_menu
  read -r -a choices || { echo ""; exit 0; }
  if [ "${#choices[@]}" -eq 0 ]; then
    continue
  fi
  run_task_queue "${choices[@]}"
done
