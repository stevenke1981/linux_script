#!/bin/bash
# 05_env_setup.sh — AI 生產環境變數與設定管理
set -e

echo "=== AI 生產環境設定 ==="
echo ""

ENV_FILE="$HOME/.ai_env"
BASHRC="$HOME/.bashrc"

# ── 1. 載入現有設定 ───────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    echo "目前設定（$ENV_FILE）："
    cat "$ENV_FILE" | grep -v "^#" | grep "=" | sed 's/=.*/=***/' | sed 's/^/  /'
    echo ""
fi

# ── 2. 設定選單 ───────────────────────────────────────────────────────────────
echo "設定選項："
echo "  [1]  CUDA 環境變數"
echo "  [2]  HuggingFace Token 與快取目錄"
echo "  [3]  llama.cpp / llama-server 設定"
echo "  [4]  Python / uv 環境"
echo "  [5]  全部設定（推薦新機器）"
echo "  [6]  顯示目前所有 AI 相關環境變數"
echo "  [0]  離開"
echo ""
read -rp "請選擇: " OPT

setup_cuda() {
    echo ""
    echo "── CUDA 設定 ──"
    CUDA_ENV='
# CUDA Toolkit
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
export CUDA_HOME=/usr/local/cuda
export CUDACXX=/usr/local/cuda/bin/nvcc'
    if ! grep -q "CUDA Toolkit" "$BASHRC"; then
        echo "$CUDA_ENV" >> "$BASHRC"
        echo "  ✓ CUDA 環境變數已加入 ~/.bashrc"
    else
        echo "  ✓ CUDA 環境變數已存在"
    fi
    eval "$CUDA_ENV" 2>/dev/null || true
}

setup_hf() {
    echo ""
    echo "── HuggingFace 設定 ──"
    read -rp "  HuggingFace Token（留空跳過）: " HF_TOKEN_INPUT
    read -rp "  模型快取目錄 [$HOME/models/hf_cache]: " HF_CACHE
    HF_CACHE="${HF_CACHE:-$HOME/models/hf_cache}"
    mkdir -p "$HF_CACHE"

    HF_ENV="
# HuggingFace
export HF_HOME=${HF_CACHE}
export HUGGINGFACE_HUB_CACHE=${HF_CACHE}
export HF_HUB_ENABLE_HF_TRANSFER=1"
    [ -n "$HF_TOKEN_INPUT" ] && HF_ENV="$HF_ENV
export HF_TOKEN=${HF_TOKEN_INPUT}"

    if ! grep -q "HuggingFace" "$BASHRC"; then
        echo "$HF_ENV" >> "$BASHRC"
        echo "  ✓ HuggingFace 設定已加入 ~/.bashrc"
    else
        echo "  ⚠ HuggingFace 設定已存在，請手動更新 ~/.bashrc"
    fi
}

setup_llama() {
    echo ""
    echo "── llama-server 設定 ──"
    read -rp "  預設模型路徑（可留空）: " DEFAULT_MODEL
    read -rp "  API Port [8080]: " LLAMA_PORT
    LLAMA_PORT="${LLAMA_PORT:-8080}"
    read -rp "  Context Size [4096]: " LLAMA_CTX
    LLAMA_CTX="${LLAMA_CTX:-4096}"

    LLAMA_ENV="
# llama-server
export LLAMA_PORT=${LLAMA_PORT}
export LLAMA_CTX_SIZE=${LLAMA_CTX}
export LLAMA_N_GPU_LAYERS=-1"
    [ -n "$DEFAULT_MODEL" ] && LLAMA_ENV="$LLAMA_ENV
export LLAMA_MODEL=${DEFAULT_MODEL}"

    if ! grep -q "llama-server" "$BASHRC"; then
        echo "$LLAMA_ENV" >> "$BASHRC"
        echo "  ✓ llama-server 設定已加入 ~/.bashrc"
    fi
}

setup_python() {
    echo ""
    echo "── Python / uv 設定 ──"
    UV_ENV='
# uv / Python
export PATH="$HOME/.local/bin:$PATH"
export UV_PYTHON_PREFERENCE=only-managed
export UV_CACHE_DIR="$HOME/.cache/uv"'
    if ! grep -q "UV_PYTHON" "$BASHRC"; then
        echo "$UV_ENV" >> "$BASHRC"
        echo "  ✓ Python/uv 設定已加入 ~/.bashrc"
    else
        echo "  ✓ Python/uv 設定已存在"
    fi
}

case "$OPT" in
    1) setup_cuda ;;
    2) setup_hf ;;
    3) setup_llama ;;
    4) setup_python ;;
    5) setup_cuda; setup_hf; setup_llama; setup_python ;;
    6)
        echo ""
        echo "目前 AI 相關環境變數："
        env | grep -E "CUDA|HF_|LLAMA|UV_|PYTHON|PATH" | sort | sed 's/^/  /'
        ;;
    *) echo "離開" ;;
esac

echo ""
echo "=== 完成 ==="
echo "執行以下指令套用設定："
echo "  source ~/.bashrc"
