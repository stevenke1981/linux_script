#!/bin/bash
# 03_llama_server_service.sh — 將 llama-server 建立為 systemd 服務
set -e

echo "=== 建立 llama-server Systemd 服務 ==="
echo ""

# ── 1. 確認 llama-server 路徑 ─────────────────────────────────────────────────
LLAMA_BIN=""
for path in "$HOME/.local/bin/llama-server" "/usr/local/bin/llama-server"; do
    if [ -f "$path" ]; then
        LLAMA_BIN="$path"
        break
    fi
done

if [ -z "$LLAMA_BIN" ]; then
    echo "✗ 找不到 llama-server，請先執行 02_gpu_ai/04b_build_llama_cpp.sh"
    exit 1
fi
echo "  llama-server 路徑：$LLAMA_BIN"
echo ""

# ── 2. 收集設定參數 ───────────────────────────────────────────────────────────
echo "[1/4] 服務設定："

# 模型檔案
DEFAULT_MODEL_DIR="$HOME/models"
echo "  模型目錄：$DEFAULT_MODEL_DIR"
GGUF_FILES=$(find "$DEFAULT_MODEL_DIR" -name "*.gguf" 2>/dev/null | head -10 || true)
if [ -n "$GGUF_FILES" ]; then
    echo "  找到的 GGUF 模型："
    echo "$GGUF_FILES" | nl -ba | sed 's/^/    /'
    echo ""
    read -rp "  輸入模型路徑（或直接貼上完整路徑）: " MODEL_PATH
else
    read -rp "  模型完整路徑（.gguf）: " MODEL_PATH
fi

# GPU layer
TOTAL_LAYERS=99
read -rp "  GPU Layers（-1=全部載入 GPU）[-1]: " GPU_LAYERS
GPU_LAYERS="${GPU_LAYERS:--1}"

# API Port
read -rp "  API Port [8080]: " API_PORT
API_PORT="${API_PORT:-8080}"

# Context
read -rp "  Context 大小 [4096]: " CTX_SIZE
CTX_SIZE="${CTX_SIZE:-4096}"

# Threads
CPU_CORES=$(nproc)
DEFAULT_THREADS=$(( CPU_CORES / 2 ))
read -rp "  CPU Threads [${DEFAULT_THREADS}]: " THREADS
THREADS="${THREADS:-$DEFAULT_THREADS}"

SERVICE_USER=$(whoami)
SERVICE_NAME="llama-server"

# ── 3. 建立 systemd service 檔 ────────────────────────────────────────────────
echo ""
echo "[2/4] 建立 systemd service..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=llama.cpp HTTP Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${HOME}
Environment="PATH=${HOME}/.local/bin:/usr/local/cuda/bin:/usr/bin:/bin"
Environment="LD_LIBRARY_PATH=/usr/local/cuda/lib64"
ExecStart=${LLAMA_BIN} \\
    --model ${MODEL_PATH} \\
    --n-gpu-layers ${GPU_LAYERS} \\
    --port ${API_PORT} \\
    --ctx-size ${CTX_SIZE} \\
    --threads ${THREADS} \\
    --host 0.0.0.0 \\
    --log-disable
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=llama-server

[Install]
WantedBy=multi-user.target
EOF

echo "  ✓ 已建立：/etc/systemd/system/${SERVICE_NAME}.service"

# ── 4. 啟動服務 ───────────────────────────────────────────────────────────────
echo ""
echo "[3/4] 啟動服務..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

sleep 3

# ── 5. 確認狀態 ───────────────────────────────────────────────────────────────
echo ""
echo "[4/4] 服務狀態："
systemctl status "$SERVICE_NAME" --no-pager | head -15

echo ""
echo "=== 完成 ==="
IP=$(hostname -I | awk '{print $1}')
echo "API 端點：http://${IP}:${API_PORT}"
echo "健康檢查：curl http://${IP}:${API_PORT}/health"
echo "OpenAI 相容：http://${IP}:${API_PORT}/v1/chat/completions"
echo ""
echo "管理指令："
echo "  sudo systemctl start/stop/restart $SERVICE_NAME"
echo "  journalctl -u $SERVICE_NAME -f"
