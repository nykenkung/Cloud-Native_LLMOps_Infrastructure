#!/usr/bin/env bash
set -e
sudo mkdir -p "$HOME/HuggingFace-Models" && sudo chown -R "$USER:$USER" "$HOME/HuggingFace-Models"
command -v huggingface-cli >/dev/null || pip install -U "huggingface_hub[cli]" --break-system-packages

TOKEN="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.cache/huggingface/token" ]; then
  TOKEN=$(cat "$HOME/.cache/huggingface/token" 2>/dev/null | tr -d '[:space:]')
fi

download_hf_file() {
  local repo="$1"
  local file="$2"
  local dest="$3"
  mkdir -p "$dest"
  if [ -f "$dest/$file" ] && [ ! -f "$dest/$file.aria2" ]; then
    echo "[SKIP] $dest/$file already exists."
    return 0
  fi

  local aria_headers=()
  local cli_args=()
  if [ -n "$TOKEN" ]; then
    aria_headers=(--header="Authorization: Bearer $TOKEN")
    cli_args=(--token "$TOKEN")
  fi

  if command -v aria2c >/dev/null 2>&1; then
    echo "[ARIA2] Downloading $file from $repo..."
    aria2c -x 16 -s 16 -k 1M -c \
      "${aria_headers[@]}" \
      "https://huggingface.co/${repo}/resolve/main/${file}" \
      -d "$dest" -o "$file"
  else
    echo "[HF-CLI] Downloading $file from $repo..."
    huggingface-cli download "$repo" "$file" --local-dir "$dest" "${cli_args[@]}"
  fi
}

echo "=== Downloading Standard GGUF LLMs (for llama.cpp / Open-WebUI) ==="
# 1. Base Qwen2.5 0.5B (Lightweight test model)
download_hf_file "Qwen/Qwen2.5-0.5B-Instruct-GGUF" "qwen2.5-0.5b-instruct-q4_k_m.gguf" "$HOME/HuggingFace-Models/Qwen2.5-0.5B-GGUF"

# 2. Qwen3.6 35B A3B Standard GGUF
download_hf_file "bartowski/Qwen_Qwen3.6-35B-A3B-GGUF" "Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf" "$HOME/HuggingFace-Models/Qwen_Qwen3.6-35B-A3B-GGUF"

# 3. Muse-Glimmer 30B Standard GGUF
download_hf_file "bartowski/Muse-Glimmer-30B-GGUF" "Muse-Glimmer-30B-Q4_K_M.gguf" "$HOME/HuggingFace-Models/Muse-Glimmer-30B"

# 4. Google Gemma 4 31B Standard GGUF
download_hf_file "bartowski/google_gemma-4-31B-it-GGUF" "google_gemma-4-31B-it-Q4_K_M.gguf" "$HOME/HuggingFace-Models/gemma-4-31B-GGUF"
ln -sf "$HOME/HuggingFace-Models/gemma-4-31B-GGUF" "$HOME/HuggingFace-Models/gemma-4-31B" 2>/dev/null || true

# Refresh GGUF router symlinks dynamically for all completed GGUFs
mkdir -p "$HOME/HuggingFace-Models/gguf"
rm -f "$HOME/HuggingFace-Models/gguf/"*.gguf
for f in $(find "$HOME/HuggingFace-Models" -maxdepth 4 -type f -name "*.gguf" ! -path "*/gguf/*" 2>/dev/null); do
  bname=$(basename "$f")
  ln -sf "$f" "$HOME/HuggingFace-Models/gguf/${bname}" 2>/dev/null || true
done
echo "[OK] Dynamic GGUF models catalog updated."
