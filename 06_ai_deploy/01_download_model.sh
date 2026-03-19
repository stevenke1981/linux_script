#!/bin/bash
# 01_download_model.sh — HuggingFace 模型下載管理
set -e

export PATH="$HOME/.local/bin:$PATH"

echo "=== HuggingFace 模型下載 ==="
echo ""

# ── 確認 huggingface_hub ──────────────────────────────────────────────────────
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    echo "安裝 huggingface_hub..."
    pip install huggingface_hub hf_transfer --quiet
fi

# ── 啟用高速傳輸 ─────────────────────────────────────────────────────────────
export HF_HUB_ENABLE_HF_TRANSFER=1

# ── 1. 選擇下載模式 ───────────────────────────────────────────────────────────
echo "下載模式："
echo "  [1] GGUF 量化模型（llama.cpp 用）"
echo "  [2] 完整模型 Repo（Transformers 用）"
echo "  [3] 單一檔案下載"
echo ""
read -rp "請選擇 [1]: " DL_MODE
DL_MODE="${DL_MODE:-1}"

# ── 設定下載目錄 ──────────────────────────────────────────────────────────────
DEFAULT_DIR="$HOME/models"
read -rp "下載目錄 [${DEFAULT_DIR}]: " MODEL_DIR
MODEL_DIR="${MODEL_DIR:-$DEFAULT_DIR}"
mkdir -p "$MODEL_DIR"

# ── 2. HuggingFace Token（私有模型需要）──────────────────────────────────────
if [ -n "$HF_TOKEN" ]; then
    echo "✓ 偵測到 HF_TOKEN 環境變數"
else
    read -rp "HuggingFace Token（公開模型可留空）: " HF_TOKEN
    [ -n "$HF_TOKEN" ] && export HF_TOKEN
fi

case "$DL_MODE" in
    1)
        echo ""
        echo "常用 GGUF 模型："
        echo "  Qwen3      : Qwen/Qwen3-8B-GGUF"
        echo "  Llama-3.1  : bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
        echo "  Gemma-3    : bartowski/gemma-3-9b-it-GGUF"
        echo "  DeepSeek   : bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF"
        echo ""
        read -rp "Repo ID (例如 Qwen/Qwen3-8B-GGUF): " REPO_ID
        echo ""
        echo "量化版本建議："
        echo "  Q4_K_M  — 品質/大小平衡（推薦）"
        echo "  Q5_K_M  — 較高品質"
        echo "  Q8_0    — 接近原始品質（需要較多 VRAM）"
        read -rp "量化版本關鍵字 [Q4_K_M]: " QUANT
        QUANT="${QUANT:-Q4_K_M}"

        python3 - <<PYEOF
import os, sys
from huggingface_hub import hf_hub_download, list_repo_files

repo_id = "${REPO_ID}"
quant = "${QUANT}"
dest = "${MODEL_DIR}"
token = os.environ.get("HF_TOKEN")

try:
    files = [f for f in list_repo_files(repo_id, token=token) if quant in f and f.endswith(".gguf")]
    if not files:
        files = [f for f in list_repo_files(repo_id, token=token) if f.endswith(".gguf")]
    if not files:
        print(f"錯誤：找不到 GGUF 檔案", file=sys.stderr)
        sys.exit(1)

    print(f"找到 {len(files)} 個 GGUF 檔案：")
    for i, f in enumerate(files):
        print(f"  [{i}] {f}")

    idx = int(input("選擇編號 [0]: ") or "0")
    fname = files[idx]
    print(f"\n下載：{fname}")
    path = hf_hub_download(repo_id=repo_id, filename=fname,
                           local_dir=dest, token=token)
    print(f"\n✓ 已下載：{path}")
except Exception as e:
    print(f"錯誤：{e}", file=sys.stderr)
    sys.exit(1)
PYEOF
        ;;
    2)
        read -rp "Repo ID (例如 Qwen/Qwen3-8B): " REPO_ID
        echo "  下載完整 Repo 到 $MODEL_DIR/$REPO_ID ..."
        python3 -c "
from huggingface_hub import snapshot_download
import os
path = snapshot_download(
    repo_id='${REPO_ID}',
    local_dir='${MODEL_DIR}/${REPO_ID}',
    token=os.environ.get('HF_TOKEN')
)
print(f'✓ 下載完成：{path}')
"
        ;;
    3)
        read -rp "Repo ID: " REPO_ID
        read -rp "檔案路徑: " FILE_PATH
        python3 -c "
from huggingface_hub import hf_hub_download
import os
path = hf_hub_download(
    repo_id='${REPO_ID}',
    filename='${FILE_PATH}',
    local_dir='${MODEL_DIR}',
    token=os.environ.get('HF_TOKEN')
)
print(f'✓ 下載完成：{path}')
"
        ;;
esac

echo ""
echo "=== 完成 ==="
echo "模型目錄："
ls -lh "$MODEL_DIR"/*.gguf 2>/dev/null || ls -lh "$MODEL_DIR" 2>/dev/null
