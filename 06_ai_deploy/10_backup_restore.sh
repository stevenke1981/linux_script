#!/bin/bash
# 10_backup_restore.sh — AI 環境備份與還原
set -e

echo "=== AI 環境備份與還原 ==="
echo ""

BACKUP_BASE="${AI_BACKUP_DIR:-$HOME/ai_backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_BASE"

# ── 選擇模式 ──────────────────────────────────────────────────────────────────
echo "模式："
echo "  [1] 備份（設定、服務定義、環境變數）"
echo "  [2] 還原"
echo "  [3] 列出備份"
echo "  [4] 匯出完整部署腳本"
echo ""
read -rp "請選擇 [1]: " MODE
MODE="${MODE:-1}"

case "$MODE" in

# ── 備份 ──────────────────────────────────────────────────────────────────────
1)
    BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"
    echo ""
    echo "備份目標：$BACKUP_DIR"
    echo ""

    # systemd service 檔案
    echo "[1/5] 備份 systemd 服務定義..."
    mkdir -p "$BACKUP_DIR/systemd"
    for svc in llama-server ai-watchdog; do
        SVC_FILE="/etc/systemd/system/${svc}.service"
        [ -f "$SVC_FILE" ] && cp "$SVC_FILE" "$BACKUP_DIR/systemd/" && echo "  ✓ ${svc}.service"
    done
    cp /etc/systemd/system/ai-watchdog.timer "$BACKUP_DIR/systemd/" 2>/dev/null || true

    # 環境變數
    echo "[2/5] 備份環境設定..."
    cp "$HOME/.bashrc" "$BACKUP_DIR/bashrc.bak" 2>/dev/null && echo "  ✓ .bashrc"
    cp "$HOME/.ai_env" "$BACKUP_DIR/ai_env.bak" 2>/dev/null || true
    cp "$HOME/.ai_models.conf" "$BACKUP_DIR/ai_models.conf.bak" 2>/dev/null || true

    # Netplan 網路設定
    echo "[3/5] 備份網路設定..."
    mkdir -p "$BACKUP_DIR/netplan"
    sudo cp /etc/netplan/*.yaml "$BACKUP_DIR/netplan/" 2>/dev/null && echo "  ✓ netplan 設定" || true

    # SSH 設定（不包含 key）
    echo "[4/5] 備份 SSH 設定..."
    sudo cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak" 2>/dev/null && echo "  ✓ sshd_config"

    # 模型清單（不備份模型本體，僅記錄）
    echo "[5/5] 記錄模型清單..."
    find "$HOME/models" -name "*.gguf" -printf "%f\t%s\n" 2>/dev/null | \
        awk '{printf "%s\t%.1f GB\n", $1, $2/1024/1024/1024}' > "$BACKUP_DIR/model_list.txt" || true
    cat "$BACKUP_DIR/model_list.txt" | sed 's/^/  /'

    # 系統資訊快照
    {
        echo "備份時間：$(date)"
        echo "主機：$(hostname)"
        echo "OS：$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
        echo "Kernel：$(uname -r)"
        echo "GPU：$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo N/A)"
        echo "CUDA：$(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d , || echo N/A)"
    } > "$BACKUP_DIR/system_info.txt"

    # 打包
    TAR_FILE="$BACKUP_BASE/ai_backup_${TIMESTAMP}.tar.gz"
    tar -czf "$TAR_FILE" -C "$BACKUP_BASE" "backup_$TIMESTAMP"
    rm -rf "$BACKUP_DIR"
    echo ""
    echo "✓ 備份完成：$TAR_FILE"
    echo "  大小：$(du -h "$TAR_FILE" | cut -f1)"
    ;;

# ── 還原 ──────────────────────────────────────────────────────────────────────
2)
    echo ""
    echo "可用備份："
    BACKUPS=()
    while IFS= read -r f; do
        BACKUPS+=("$f")
    done < <(ls -t "$BACKUP_BASE"/*.tar.gz 2>/dev/null)

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo "  找不到備份檔案（$BACKUP_BASE）"
        exit 1
    fi

    for i in "${!BACKUPS[@]}"; do
        SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        echo "  [$i] $(basename "${BACKUPS[$i]}") ($SIZE)"
    done
    echo ""
    read -rp "選擇備份編號: " BACKUP_IDX
    RESTORE_FILE="${BACKUPS[$BACKUP_IDX]}"

    echo "還原：$RESTORE_FILE"
    read -rp "確認還原？現有設定將被覆蓋 [y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

    # 解壓縮
    RESTORE_DIR="$BACKUP_BASE/restore_tmp"
    rm -rf "$RESTORE_DIR"
    mkdir -p "$RESTORE_DIR"
    tar -xzf "$RESTORE_FILE" -C "$RESTORE_DIR"
    INNER=$(ls "$RESTORE_DIR")

    # 還原 systemd
    if ls "$RESTORE_DIR/$INNER/systemd/"*.service &>/dev/null; then
        sudo cp "$RESTORE_DIR/$INNER/systemd/"*.service /etc/systemd/system/ 2>/dev/null || true
        sudo cp "$RESTORE_DIR/$INNER/systemd/"*.timer  /etc/systemd/system/ 2>/dev/null || true
        sudo systemctl daemon-reload
        echo "  ✓ systemd 服務已還原"
    fi

    # 還原 .bashrc（備份後還原）
    if [ -f "$RESTORE_DIR/$INNER/bashrc.bak" ]; then
        cp "$HOME/.bashrc" "$HOME/.bashrc.pre_restore_$(date +%s)"
        cp "$RESTORE_DIR/$INNER/bashrc.bak" "$HOME/.bashrc"
        echo "  ✓ .bashrc 已還原"
    fi

    rm -rf "$RESTORE_DIR"
    echo ""
    echo "✓ 還原完成，請執行：source ~/.bashrc && sudo systemctl daemon-reload"
    ;;

# ── 列出備份 ──────────────────────────────────────────────────────────────────
3)
    echo ""
    echo "備份清單（$BACKUP_BASE）："
    ls -lht "$BACKUP_BASE"/*.tar.gz 2>/dev/null | \
        awk '{printf "  %-10s  %s\n", $5, $9}' || echo "  無備份"
    ;;

# ── 匯出部署腳本 ──────────────────────────────────────────────────────────────
4)
    DEPLOY_SCRIPT="$HOME/ai_deploy_$(hostname)_$TIMESTAMP.sh"
    echo ""
    echo "產生部署腳本：$DEPLOY_SCRIPT"

    # 從現有 systemd service 提取參數
    SVC_FILE="/etc/systemd/system/llama-server.service"
    MODEL_PATH=""; API_PORT="8080"; GPU_LAYERS="-1"; CTX_SIZE="4096"
    if [ -f "$SVC_FILE" ]; then
        MODEL_PATH=$(grep -- "--model " "$SVC_FILE" | grep -oP '(?<=--model )\S+' || echo "")
        API_PORT=$(grep -- "--port " "$SVC_FILE" | grep -oP '(?<=--port )\d+' || echo "8080")
        GPU_LAYERS=$(grep -- "--n-gpu-layers " "$SVC_FILE" | grep -oP '(?<=--n-gpu-layers )-?\d+' || echo "-1")
        CTX_SIZE=$(grep -- "--ctx-size " "$SVC_FILE" | grep -oP '(?<=--ctx-size )\d+' || echo "4096")
    fi

    tee "$DEPLOY_SCRIPT" > /dev/null <<EOF
#!/bin/bash
# AI 環境自動部署腳本
# 產生自：$(hostname) 於 $(date)
# ============================================
set -e

# 1. 安裝依賴
bash ~/linux_script/01_system/02_install_build_essential.sh
bash ~/linux_script/02_gpu_ai/01_install_nvidia_driver.sh
# ↑ 重開機後繼續 ↑

# 2. CUDA
bash ~/linux_script/02_gpu_ai/02_install_cuda.sh
source ~/.bashrc

# 3. Python
bash ~/linux_script/02_gpu_ai/03_install_python.sh
source ~/.bashrc

# 4. llama.cpp
bash ~/linux_script/02_gpu_ai/04b_build_llama_cpp.sh

# 5. 下載模型
# 手動執行：bash ~/linux_script/06_ai_deploy/01_download_model.sh

# 6. 啟動服務
MODEL_PATH="${MODEL_PATH:-\$HOME/models/your_model.gguf}"
llama-server \\
    --model "\$MODEL_PATH" \\
    --n-gpu-layers ${GPU_LAYERS} \\
    --port ${API_PORT} \\
    --ctx-size ${CTX_SIZE} \\
    --host 0.0.0.0 \\
    --log-disable &

echo "AI 服務啟動完成：http://\$(hostname -I | awk '{print \$1}'):${API_PORT}"
EOF
    chmod +x "$DEPLOY_SCRIPT"
    echo "✓ 部署腳本已產生：$DEPLOY_SCRIPT"
    ;;

esac

echo ""
echo "=== 完成 ==="
