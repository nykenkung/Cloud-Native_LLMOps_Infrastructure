#!/usr/bin/env bash
set -e

if [ -z "$KUBECONFIG" ]; then
  if [ -r "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
  elif [ -r "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
  fi
fi

# =====================================================================
#  [110] Interactive LLM CLI Chat
#  Select an available model and start a multi-turn Q&A session
#  Supports: LiteLLM Gateway (/v1) and llama.cpp direct (/v1)
# =====================================================================

# --- Configuration ---
LITELLM_API_KEY="${LITELLM_API_KEY:-$(kubectl get secret -n litellm my-litellm-postgres-config -o jsonpath='{.data.master-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"
LLAMA_API_KEY="${LLAMA_API_KEY:-$(kubectl get secret -n llamacpp-rocm llamacpp-api-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d 2>/dev/null || echo '')}"
MAX_TOKENS=1024
TEMPERATURE=0.7
HISTORY_FILE="${HOME}/.llm-cli-history"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# --- Resolve Service Endpoints ---
resolve_endpoints() {
  LITELLM_IP=$(kubectl get svc -n litellm litellm -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
               kubectl get svc -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")
  LLAMA_IP=$(kubectl get svc -n llamacpp-rocm llamacpp-rocm-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
            kubectl get svc -n llamacpp-rocm -l app.kubernetes.io/name=llamacpp-rocm -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

  if [ -n "$LITELLM_IP" ]; then
    LITELLM_BASE="http://${LITELLM_IP}:4000"
  fi
  if [ -n "$LLAMA_IP" ]; then
    LLAMA_BASE="http://${LLAMA_IP}:8080"
  fi
}

# --- Health Check ---
check_health() {
  local base_url=$1
  local name=$2
  local health
  # Try liveliness first (LiteLLM returns "I'm alive!")
  health=$(curl -s --max-time 5 "${base_url}/health/liveliness" 2>/dev/null || echo "")
  if echo "$health" | grep -qi "ok\|alive\|status\|healthy"; then
    return 0
  fi
  # Try authenticated /health
  health=$(curl -s --max-time 5 -H "Authorization: Bearer ${LITELLM_API_KEY}" "${base_url}/health" 2>/dev/null || echo "")
  if echo "$health" | grep -qi "ok\|alive\|status\|healthy"; then
    return 0
  fi
  # Try unauthenticated /health (llama.cpp)
  health=$(curl -s --max-time 5 "${base_url}/health" 2>/dev/null || echo "")
  if echo "$health" | grep -qi "ok\|alive\|status\|healthy"; then
    return 0
  fi
  return 1
}

# --- Discover Models ---
discover_models() {
  local models=()
  local sources=()
  local idx=0

  # 1. Query LiteLLM /v1/models
  if [ -n "$LITELLM_BASE" ]; then
    if check_health "$LITELLM_BASE" "LiteLLM"; then
      local resp
      resp=$(curl -s --max-time 10 \
        -H "Authorization: Bearer ${LITELLM_API_KEY}" \
        "${LITELLM_BASE}/v1/models" 2>/dev/null || echo "")
      if echo "$resp" | grep -q '"data"'; then
        local litellm_models
        litellm_models=$(echo "$resp" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//')
        while IFS= read -r m; do
          if [ -n "$m" ] && [ "$m" != "default" ] && [ "$m" != "llm" ] && [ "$m" != "*" ]; then
            models+=("$m")
            sources+=("LiteLLM")
            idx=$((idx + 1))
          fi
        done <<< "$litellm_models"
      fi
    else
      echo -e "${YELLOW}[WARN] LiteLLM (${LITELLM_BASE}) is not healthy — skipping${RESET}"
    fi
  fi

  # 2. Query llama.cpp /v1/models (direct)
  if [ -n "$LLAMA_BASE" ]; then
    if check_health "$LLAMA_BASE" "llama.cpp"; then
      local resp
      resp=$(curl -s --max-time 10 \
        -H "Authorization: Bearer ${LLAMA_API_KEY}" \
        "${LLAMA_BASE}/v1/models" 2>/dev/null || echo "")
      if echo "$resp" | grep -q '"data"'; then
        local llama_models
        llama_models=$(echo "$resp" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//')
        while IFS= read -r m; do
          if [ -n "$m" ] && [ "$m" != "default" ] && [ "$m" != "llm" ] && [ "$m" != "*" ]; then
            # Avoid duplicates already in the list
            local dup=0
            for existing in "${models[@]}"; do
              if [ "$existing" = "$m" ]; then dup=1; break; fi
            done
            if [ "$dup" -eq 0 ]; then
              models+=("$m")
              sources+=("llama.cpp-direct")
              idx=$((idx + 1))
            fi
          fi
        done <<< "$llama_models"
      fi
    else
      echo -e "${YELLOW}[WARN] llama.cpp (${LLAMA_BASE}) is not healthy — skipping${RESET}"
    fi
  fi

  # Reorder so qwen2.5-0.5b-instruct-q4_k_m is first (default)
  local sorted_models=()
  local sorted_sources=()
  local default_target="qwen2.5-0.5b-instruct-q4_k_m"

  for i in "${!models[@]}"; do
    if [ "${models[$i]}" = "$default_target" ]; then
      sorted_models+=("${models[$i]}")
      sorted_sources+=("${sources[$i]}")
      break
    fi
  done

  for i in "${!models[@]}"; do
    if [ "${models[$i]}" != "$default_target" ]; then
      sorted_models+=("${models[$i]}")
      sorted_sources+=("${sources[$i]}")
    fi
  done

  MODEL_LIST=("${sorted_models[@]}")
  SOURCE_LIST=("${sorted_sources[@]}")
}

# --- Model Selection Menu ---
select_model() {
  echo ""
  echo -e "${BOLD}=================================================================="
  echo -e " [110] Interactive LLM CLI Chat"
  echo -e "==================================================================${RESET}"

  if [ ${#MODEL_LIST[@]} -eq 0 ]; then
    echo -e "${RED}[FAIL] No models discovered from LiteLLM or llama.cpp.${RESET}"
    echo "       Ensure at least one backend is running with a loaded model."
    echo "       - LiteLLM: kubectl get pods -n litellm"
    echo "       - llama.cpp: kubectl get pods -n llamacpp-rocm"
    exit 1
  fi

  echo ""
  echo -e "${CYAN}Available Models:${RESET}"
  echo ""
  local default_choice=1
  for i in "${!MODEL_LIST[@]}"; do
    local num=$((i + 1))
    local tag=""
    if [ "${MODEL_LIST[$i]}" = "qwen2.5-0.5b-instruct-q4_k_m" ]; then
      tag=" ${YELLOW}(Default)${RESET}"
      default_choice=$num
    fi
    printf "  ${GREEN}%2d)${RESET} %-40s ${DIM}[%s]${RESET}%b\n" "$num" "${MODEL_LIST[$i]}" "${SOURCE_LIST[$i]}" "$tag"
  done
  echo ""

  local choice
  while true; do
    echo -ne "${BOLD}Select a model [1-${#MODEL_LIST[@]}, default: ${default_choice}]: ${RESET}"
    read -r choice
    if [ -z "$choice" ]; then
      choice="$default_choice"
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#MODEL_LIST[@]}" ]; then
      SELECTED_MODEL="${MODEL_LIST[$((choice - 1))]}"
      SELECTED_SOURCE="${SOURCE_LIST[$((choice - 1))]}"
      break
    else
      echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#MODEL_LIST[@]}.${RESET}"
    fi
  done

  # Determine API endpoint based on source
  if [ "$SELECTED_SOURCE" = "llama.cpp-direct" ]; then
    API_BASE="$LLAMA_BASE"
    API_KEY="$LLAMA_API_KEY"
  else
    API_BASE="$LITELLM_BASE"
    API_KEY="$LITELLM_API_KEY"
  fi

  echo ""
  echo -e "${GREEN}[OK] Model: ${BOLD}${SELECTED_MODEL}${RESET}${GREEN} via ${SELECTED_SOURCE}${RESET}"
  echo -e "${DIM}     Endpoint: ${API_BASE}/v1/chat/completions${RESET}"
}

# --- Build JSON Payload ---
build_payload() {
  local messages_json=$1
  cat <<EOF
{
  "model": "${SELECTED_MODEL}",
  "messages": ${messages_json},
  "max_tokens": ${MAX_TOKENS},
  "temperature": ${TEMPERATURE},
  "stream": false
}
EOF
}

# --- Send Chat Completion ---
send_chat() {
  local payload=$1
  local tmpfile curl_code http_code resp content

  tmpfile=$(mktemp)
  curl_code=0
  http_code=$(curl -s -w "%{http_code}" -o "$tmpfile" --max-time 180 \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${API_BASE}/v1/chat/completions") || curl_code=$?

  resp=$(cat "$tmpfile" 2>/dev/null)
  rm -f "$tmpfile"

  if [ "$curl_code" -eq 28 ]; then
    echo -e "${RED}[ERROR] Request timed out (exceeded 180s). The model may still be generating or the backend is busy.${RESET}"
    return 1
  elif [ "$curl_code" -ne 0 ]; then
    echo -e "${RED}[ERROR] Network error: curl returned exit code ${curl_code}.${RESET}"
    return 1
  fi

  if [ -z "$resp" ]; then
    echo -e "${RED}[ERROR] Empty response received from API (HTTP ${http_code}).${RESET}"
    return 1
  fi

  # Parse response using python
  if command -v python3 &>/dev/null; then
    content=$(python3 -c "
import sys, json, re
try:
    data = json.loads(sys.argv[1])
    if 'error' in data:
        err = data['error'].get('message', str(data['error']))
        print(f'API_ERROR: {err}')
    elif 'choices' in data and len(data['choices']) > 0:
        msg = data['choices'][0].get('message', {})
        text = msg.get('content') or ''
        reasoning = msg.get('reasoning_content') or ''

        # Extract embedded thinking tags (<think>, <thought>, <thinking>)
        think_match = re.search(r'<(?:think|thought|thinking)>(.*?)</(?:think|thought|thinking)>', text, re.DOTALL)
        if think_match:
            embedded_reason = think_match.group(1).strip()
            answer_text = re.sub(r'<(?:think|thought|thinking)>.*?</(?:think|thought|thinking)>', '', text, flags=re.DOTALL).strip()
            if embedded_reason and answer_text:
                print(f'\033[1;33m[Thinking Process]\033[0m\n\033[2m{embedded_reason}\033[0m\n\n\033[1;32m[Answer]\033[0m\n{answer_text}')
            elif embedded_reason:
                print(f'\033[1;33m[Thinking Process]\033[0m\n\033[2m{embedded_reason}\033[0m')
            else:
                print(text)
        elif reasoning:
            reasoning = reasoning.strip()
            answer_text = text.strip()
            if reasoning and answer_text:
                print(f'\033[1;33m[Thinking Process]\033[0m\n\033[2m{reasoning}\033[0m\n\n\033[1;32m[Answer]\033[0m\n{answer_text}')
            elif reasoning:
                print(f'\033[1;33m[Thinking Process]\033[0m\n\033[2m{reasoning}\033[0m')
            else:
                print(answer_text)
        else:
            print(text)
    elif 'message' in data:
        print(f'API_ERROR: {data[\"message\"]}')
except Exception as e:
    pass
" "$resp" 2>/dev/null)
  fi

  if [[ "$content" =~ ^API_ERROR:\ (.*) ]]; then
    echo -e "${RED}[ERROR] ${BASH_REMATCH[1]}${RESET}"
  elif [ -n "$content" ]; then
    echo "$content"
  else
    # Fallback grep if python is unavailable
    local fallback
    fallback=$(echo "$resp" | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//;s/"$//')
    if [ -n "$fallback" ]; then
      echo "$fallback"
    else
      echo -e "${RED}[ERROR] HTTP ${http_code}: Failed to parse model response.${RESET}"
      echo -e "${DIM}Raw output: ${resp}${RESET}"
    fi
  fi
}

# --- Interactive Chat Loop ---
run_chat() {
  echo ""
  echo -e "${BOLD}=================================================================="
  echo -e " LLM Interactive Chat Session"
  echo -e "==================================================================${RESET}"
  echo -e "${DIM} Model   : ${SELECTED_MODEL}"
  echo -e " Backend : ${SELECTED_SOURCE} (${API_BASE})"
  echo -e " Params  : max_tokens=${MAX_TOKENS}, temperature=${TEMPERATURE}"
  echo -e ""
  echo -e " Commands:"
  echo -e "   /clear   - Clear conversation history and start fresh"
  echo -e "   /model   - Switch to a different model"
  echo -e "   /tokens  - Change max_tokens   (e.g. /tokens 4096)"
  echo -e "   /temp    - Change temperature   (e.g. /temp 0.3)"
  echo -e "   /history - Show conversation turn count"
  echo -e "   /exit    - Exit the chat session"
  echo -e "==================================================================${RESET}"
  echo ""

  # Conversation history as a JSON array string
  local messages="[]"
  local turn=0

  while true; do
    echo -ne "${GREEN}You [turn $((turn + 1))]: ${RESET}"
    read -r user_input

    # Handle empty input
    if [ -z "$user_input" ]; then
      continue
    fi

    # Handle slash commands
    case "$user_input" in
      /exit|/quit|/q)
        echo ""
        echo -e "${CYAN}[INFO] Chat session ended. Goodbye!${RESET}"
        break
        ;;
      /clear)
        messages="[]"
        turn=0
        echo -e "${CYAN}[INFO] Conversation history cleared.${RESET}"
        echo ""
        continue
        ;;
      /model)
        select_model
        messages="[]"
        turn=0
        echo -e "${CYAN}[INFO] Switched model. Conversation history cleared.${RESET}"
        echo ""
        continue
        ;;
      /tokens\ *)
        local new_tokens="${user_input#/tokens }"
        if [[ "$new_tokens" =~ ^[0-9]+$ ]]; then
          MAX_TOKENS=$new_tokens
          echo -e "${CYAN}[INFO] max_tokens set to ${MAX_TOKENS}${RESET}"
        else
          echo -e "${RED}[ERROR] Invalid value. Usage: /tokens 4096${RESET}"
        fi
        continue
        ;;
      /temp\ *)
        local new_temp="${user_input#/temp }"
        if [[ "$new_temp" =~ ^[0-9]*\.?[0-9]+$ ]]; then
          TEMPERATURE=$new_temp
          echo -e "${CYAN}[INFO] temperature set to ${TEMPERATURE}${RESET}"
        else
          echo -e "${RED}[ERROR] Invalid value. Usage: /temp 0.3${RESET}"
        fi
        continue
        ;;
      /history)
        echo -e "${CYAN}[INFO] Current conversation: ${turn} turn(s)${RESET}"
        continue
        ;;
      /help)
        echo -e "${DIM}/clear /model /tokens N /temp N /history /exit${RESET}"
        continue
        ;;
    esac

    # Append user message to history
    if command -v python3 &>/dev/null; then
      messages=$(python3 -c "
import sys, json
msgs = json.loads(sys.argv[1])
msgs.append({'role': 'user', 'content': sys.argv[2]})
print(json.dumps(msgs))
" "$messages" "$user_input")
    else
      # Fallback: escape special characters in user input for JSON
      local escaped
      escaped=$(echo "$user_input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
      if [ "$messages" = "[]" ]; then
        messages="[{\"role\":\"user\",\"content\":\"${escaped}\"}]"
      else
        messages="${messages%]},{\"role\":\"user\",\"content\":\"${escaped}\"}]"
      fi
    fi

    # Build and send request
    local payload
    payload=$(build_payload "$messages")

    echo -ne "${YELLOW}${DIM}(thinking...)${RESET}"

    local reply
    reply=$(send_chat "$payload")

    # Clear "thinking..." and print reply
    echo -ne "\r\033[K"
    echo -e "${CYAN}AI: ${RESET}${reply}"
    echo ""

    # Append assistant reply to history
    if command -v python3 &>/dev/null; then
      messages=$(python3 -c "
import sys, json
msgs = json.loads(sys.argv[1])
msgs.append({'role': 'assistant', 'content': sys.argv[2]})
print(json.dumps(msgs))
" "$messages" "$reply")
    else
      local escaped_reply
      escaped_reply=$(echo "$reply" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
      messages="${messages%]},{\"role\":\"assistant\",\"content\":\"${escaped_reply}\"}]"
    fi

    turn=$((turn + 1))

    # Save last exchange to history file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Model: ${SELECTED_MODEL} | You: ${user_input}" >> "$HISTORY_FILE" 2>/dev/null || true
  done
}

# --- Main ---
main() {
  echo ""
  echo "=================================================================="
  echo " [110] Interactive LLM CLI Chat"
  echo "   Select an available model and start a multi-turn Q&A session"
  echo "=================================================================="
  echo ""
  echo "Discovering available AI backends..."
  echo ""

  resolve_endpoints

  if [ -z "$LITELLM_BASE" ] && [ -z "$LLAMA_BASE" ]; then
    echo -e "${RED}[FAIL] Neither LiteLLM nor llama.cpp service IP could be resolved.${RESET}"
    echo "       Ensure the services are deployed:"
    echo "         kubectl get svc -n litellm"
    echo "         kubectl get svc -n llamacpp-rocm"
    exit 1
  fi

  [ -n "$LITELLM_BASE" ] && echo -e "  ${GREEN}✓${RESET} LiteLLM Gateway  : ${LITELLM_BASE}"
  [ -n "$LLAMA_BASE" ]   && echo -e "  ${GREEN}✓${RESET} llama.cpp Direct : ${LLAMA_BASE}"

  discover_models
  select_model
  run_chat

  echo ""
  echo "=================================================================="
  echo " [OK] LLM CLI Chat Session Finished."
  echo "=================================================================="
}

main "$@"
