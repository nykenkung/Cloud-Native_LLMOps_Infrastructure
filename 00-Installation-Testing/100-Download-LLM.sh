#!/usr/bin/env bash
# =====================================================================
#  [100] Download GGUF & Full-Directory HuggingFace Models
#  Multi-Threaded Aria2 / HuggingFace CLI Downloader
#
#  Simple Installation Command:
#    pip install "huggingface_hub[cli]" --break-system-packages
#    huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf --local-dir ~/HuggingFace-Models/GGUF
# =====================================================================
set -uo pipefail

# ==============================================================================
# Configuration: Available Models
#   - GGUF single file : "<repo> <default_file.gguf>"   -> saved to ~/HuggingFace-Models/GGUF/
#   - Full directory   : "<repo>"                       -> saved to ~/HuggingFace-Models/<repo_name>/
#                        "<repo> <custom_folder_name>"  -> saved to ~/HuggingFace-Models/<custom_folder_name>/
# ==============================================================================
MODELS=(
  "bartowski/Qwen_Qwen3.6-35B-A3B-GGUF Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf"
  "Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf"
  "bartowski/Muse-Glimmer-30B-GGUF Muse-Glimmer-30B-Q4_K_M.gguf"
  "bartowski/google_gemma-4-31B-it-GGUF google_gemma-4-31B-it-Q4_K_M.gguf"
  "unsloth/MiniMax-H3-GGUF qwen3vl_32b_minimax_h3-Q4_K_M.gguf"
  "unsloth/Qwen-Image-2.1-Turbo-GGUF qwen-image-2.1-turbo-Q8_0.gguf"
  "bluryar/VoxCPM-GGUF voxcpm-0.5b-q4_k_m.gguf"
)

BASE_DIR="$HOME/HuggingFace-Models"
GGUF_DIR="$BASE_DIR/GGUF"

# ==============================================================================
# Environment Setup
# ==============================================================================
if [ ! -d "$GGUF_DIR" ] || [ ! -w "$GGUF_DIR" ]; then
  sudo mkdir -p "$GGUF_DIR" && sudo chown -R "$USER:$USER" "$BASE_DIR"
fi

TOKEN="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.cache/huggingface/token" ]; then
  TOKEN=$(tr -d '[:space:]' < "$HOME/.cache/huggingface/token" 2>/dev/null || true)
fi

HF_CMD=""
ensure_hf_cli() {
  if [ -n "$HF_CMD" ]; then
    return 0
  fi
  if command -v huggingface-cli >/dev/null 2>&1; then
    HF_CMD="huggingface-cli"
  elif command -v hf >/dev/null 2>&1; then
    HF_CMD="hf"
  else
    echo "[INFO] Installing huggingface_hub[cli]..."
    pip install -U "huggingface_hub[cli]" --break-system-packages
    if command -v huggingface-cli >/dev/null 2>&1; then
      HF_CMD="huggingface-cli"
    else
      HF_CMD="hf"
    fi
  fi
}

# ==============================================================================
# Helper Functions
# ==============================================================================
parse_model_entry() {
  local entry="$1"
  M_REPO=""
  M_ARG=""
  read -r M_REPO M_ARG <<< "$entry"

  if [[ "${M_ARG,,}" == *.gguf ]]; then
    M_TYPE="gguf"
    M_TARGET="$M_ARG"
  else
    M_TYPE="dir"
    M_TARGET="${M_ARG:-${M_REPO##*/}}"
  fi
}

download_hf_file() {
  local repo="$1"
  local file="$2"
  local out_name
  out_name=$(basename "$file")

  mkdir -p "$GGUF_DIR"
  if [ -f "$GGUF_DIR/$out_name" ] && [ ! -f "$GGUF_DIR/$out_name.aria2" ]; then
    echo "[SKIP] $GGUF_DIR/$out_name already exists."
    return 0
  fi

  local aria_headers=()
  local cli_args=()
  if [ -n "$TOKEN" ]; then
    aria_headers=(--header="Authorization: Bearer $TOKEN")
    cli_args=(--token "$TOKEN")
  fi

  if command -v aria2c >/dev/null 2>&1; then
    echo "[ARIA2] Downloading $out_name from $repo..."
    aria2c -x 16 -s 16 -k 1M -c \
      "${aria_headers[@]}" \
      "https://huggingface.co/${repo}/resolve/main/${file}" \
      -d "$GGUF_DIR" -o "$out_name"
  else
    ensure_hf_cli
    echo "[HF-CLI] Downloading $out_name from $repo..."
    "$HF_CMD" download "$repo" "$file" --local-dir "$GGUF_DIR" "${cli_args[@]}"
    # Flatten if the file was inside a repo subdirectory
    if [ "$file" != "$out_name" ] && [ -f "$GGUF_DIR/$file" ]; then
      mv -f "$GGUF_DIR/$file" "$GGUF_DIR/$out_name"
      rmdir -p "$(dirname "$GGUF_DIR/$file")" 2>/dev/null || true
    fi
  fi
}

download_hf_repo() {
  local repo="$1"
  local folder_name="$2"
  local target_dir="$BASE_DIR/$folder_name"

  ensure_hf_cli
  mkdir -p "$target_dir"

  local cli_args=()
  if [ -n "$TOKEN" ]; then
    cli_args=(--token "$TOKEN")
  fi

  echo "[HF-CLI] Downloading full repository \"$repo\" -> \"$target_dir\"..."
  "$HF_CMD" download "$repo" --local-dir "$target_dir" "${cli_args[@]}"
}

fetch_gguf_variants() {
  local repo="$1"
  python3 - "$repo" "$TOKEN" <<'PYEOF'
import json, sys, urllib.request

repo = sys.argv[1]
token = sys.argv[2]

def fmt_size(b):
    if not b:
        return "unknown size"
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if b < 1024.0:
            return f"{b:.2f} {unit}"
        b /= 1024.0
    return f"{b:.2f} PB"

headers = {"User-Agent": "gguf-downloader/1.0"}
if token:
    headers["Authorization"] = f"Bearer {token}"

url = f"https://huggingface.co/api/models/{repo}/tree/main?recursive=true"
try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        items = json.loads(resp.read().decode("utf-8"))
    ggufs = [
        (item["path"], fmt_size(item.get("size", 0)))
        for item in items
        if item.get("type") == "file" and item.get("path", "").lower().endswith(".gguf")
    ]
    ggufs.sort(key=lambda x: x[0].lower())
    for path, size in ggufs:
        print(f"{path}\t{size}")
except Exception:
    sys.exit(1)
PYEOF
}

select_and_download_quant() {
  local repo="$1"
  local default_file="$2"

  echo ""
  echo "Fetching available GGUF quantizations for \"$repo\"..."
  local variants=()
  while IFS= read -r line; do
    [ -n "$line" ] && variants+=("$line")
  done < <(fetch_gguf_variants "$repo" 2>/dev/null || true)

  if [ "${#variants[@]}" -eq 0 ]; then
    echo "[WARN] Could not fetch remote GGUF list. Downloading default: $default_file"
    download_hf_file "$repo" "$default_file"
    return
  fi

  echo ""
  echo "=== Available GGUF Quantizations for \"$repo\" ==="
  echo "[0] Download Default (\"$default_file\")"
  local idx=1
  for entry in "${variants[@]}"; do
    local fpath="${entry%%$'\t'*}"
    local fsize="${entry#*$'\t'}"
    printf "[%d] %s (%s)\n" "$idx" "$fpath" "$fsize"
    ((idx++))
  done
  echo "[b] Back to main menu"
  echo ""

  local qchoice
  read -r -p "Select quantization to download: " qchoice
  if [[ "${qchoice,,}" == "b" || -z "$qchoice" ]]; then
    return
  elif [[ "$qchoice" == "0" ]]; then
    download_hf_file "$repo" "$default_file"
  elif [[ "$qchoice" =~ ^[0-9]+$ ]] && [ "$qchoice" -ge 1 ] && [ "$qchoice" -le "${#variants[@]}" ]; then
    local selected="${variants[$((qchoice - 1))]}"
    local sel_file="${selected%%$'\t'*}"
    download_hf_file "$repo" "$sel_file"
  else
    echo "[ERROR] Invalid selection."
  fi
}

install_all_models() {
  echo ""
  echo "=== Installing All Configured Models ==="
  for entry in "${MODELS[@]}"; do
    parse_model_entry "$entry"
    if [[ "$M_TYPE" == "gguf" ]]; then
      download_hf_file "$M_REPO" "$M_TARGET"
    else
      download_hf_repo "$M_REPO" "$M_TARGET"
    fi
  done
}

# ==============================================================================
# Interactive Main Loop
# ==============================================================================
DELETE_LETTERS=(B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

while true; do
  echo ""
  echo "=================================================================="
  echo " Available Models to Install"
  echo "   GGUF -> $GGUF_DIR"
  echo "   DIR  -> $BASE_DIR/<model_folder>"
  echo "=================================================================="
  echo "[0] Install All"
  for i in "${!MODELS[@]}"; do
    parse_model_entry "${MODELS[$i]}"
    if [[ "$M_TYPE" == "gguf" ]]; then
      printf "[%d] [GGUF] Install \"%s\"\n" "$((i + 1))" "$M_REPO"
    else
      printf "[%d] [DIR ] Install \"%s\" (-> %s/)\n" "$((i + 1))" "$M_REPO" "$M_TARGET"
    fi
  done

  echo ""
  echo "=================================================================="
  echo " Downloaded Models in $BASE_DIR"
  echo "=================================================================="
  downloaded_paths=()
  downloaded_types=()

  shopt -s nullglob
  for f in "$GGUF_DIR"/*.gguf; do
    downloaded_paths+=("$f")
    downloaded_types+=("GGUF")
  done
  for d in "$BASE_DIR"/*/; do
    d="${d%/}"
    bname=$(basename "$d")
    if [[ "$bname" == "GGUF" ]]; then
      continue
    fi
    downloaded_paths+=("$d")
    downloaded_types+=("DIR ")
  done
  shopt -u nullglob

  if [ "${#downloaded_paths[@]}" -eq 0 ]; then
    echo "(No models downloaded yet)"
  else
    echo "[A] Delete All"
    max_display="${#DELETE_LETTERS[@]}"
    for i in "${!downloaded_paths[@]}"; do
      if [ "$i" -ge "$max_display" ]; then
        echo "... ($(( ${#downloaded_paths[@]} - max_display )) more items not shown)"
        break
      fi
      item_path="${downloaded_paths[$i]}"
      item_type="${downloaded_types[$i]}"
      item_name=$(basename "$item_path")
      item_size=$(du -sh "$item_path" 2>/dev/null | cut -f1)
      printf "[%s] [%s] Delete \"%s\" (%s)\n" "${DELETE_LETTERS[$i]}" "$item_type" "$item_name" "$item_size"
    done
  fi

  echo ""
  read -r -p "Enter your choice (or 'exit' to quit): " choice
  choice_upper="${choice^^}"

  if [[ "$choice_upper" == "EXIT" || "$choice_upper" == "QUIT" ]]; then
    echo "Exiting."
    break
  elif [[ "$choice" == "0" ]]; then
    install_all_models
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#MODELS[@]}" ]; then
    parse_model_entry "${MODELS[$((choice - 1))]}"
    if [[ "$M_TYPE" == "gguf" ]]; then
      select_and_download_quant "$M_REPO" "$M_TARGET"
    else
      download_hf_repo "$M_REPO" "$M_TARGET"
    fi
  elif [[ "$choice_upper" == "A" ]]; then
    if [ "${#downloaded_paths[@]}" -eq 0 ]; then
      echo "[INFO] No models to delete."
    else
      read -r -p "Delete ALL ${#downloaded_paths[@]} downloaded models (GGUF files & model directories)? [y/N]: " confirm
      if [[ "${confirm,,}" == "y" ]]; then
        for i in "${!downloaded_paths[@]}"; do
          target="${downloaded_paths[$i]}"
          ttype="${downloaded_types[$i]}"
          if [[ "$ttype" == "GGUF" ]]; then
            rm -f "$target" "${target}.aria2"
          elif [[ -n "$target" && "$target" == "$BASE_DIR/"* && "$target" != "$GGUF_DIR" ]]; then
            rm -rf "$target"
          fi
        done
        echo "[OK] All downloaded models deleted."
      else
        echo "[CANCELLED]"
      fi
    fi
  elif [[ "$choice_upper" =~ ^[B-Z]$ ]]; then
    letter_idx=-1
    for i in "${!DELETE_LETTERS[@]}"; do
      if [[ "${DELETE_LETTERS[$i]}" == "$choice_upper" ]]; then
        letter_idx="$i"
        break
      fi
    done

    if [ "$letter_idx" -ge 0 ] && [ "$letter_idx" -lt "${#downloaded_paths[@]}" ]; then
      target="${downloaded_paths[$letter_idx]}"
      ttype="${downloaded_types[$letter_idx]}"
      target_name=$(basename "$target")
      read -r -p "Delete [${ttype// /}] \"$target_name\"? [y/N]: " confirm
      if [[ "${confirm,,}" == "y" ]]; then
        if [[ "$ttype" == "GGUF" ]]; then
          rm -f "$target" "${target}.aria2"
        elif [[ -n "$target" && "$target" == "$BASE_DIR/"* && "$target" != "$GGUF_DIR" ]]; then
          rm -rf "$target"
        fi
        echo "[OK] Deleted \"$target_name\"."
      else
        echo "[CANCELLED]"
      fi
    else
      echo "[ERROR] Invalid selection."
    fi
  else
    echo "[ERROR] Invalid input. Please choose a valid option or type 'exit'."
  fi
done