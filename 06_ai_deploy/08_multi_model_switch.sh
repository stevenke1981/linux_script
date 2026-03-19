#!/bin/bash
# 08_multi_model_switch.sh — 多模型切換管理
set -e

export PATH="$HOME/.local/bin:$PATH"

echo "=== 多模型切換管理 ==="
echo ""

MODELS_DIR="${MODELS_DIR:-$HOME/models}"
CURRENT_LINK="$MODELS_DIR/current.gguf"
CONFIG_FILE="$HOME/.ai_models.conf"

# ── 1. 列出可用模型 ───────────────────────────────────────────────────────────
echo "[1] 掃描可用模型（$MODELS_DIR）："
if [ ! -d "$MODELS_DIR" ]; then
    echo "  模型目錄不存在：$MODELS_DIR"
    mkdir -p "$MODELS_DIR"
fi

MODELS=()
while IFS= read -r f; do
    MODELS+=("$f")
done < <(find "$MODELS_DIR" -maxdepth 3 -name "*.gguf" 2>/dev/null | sort)

if [ ${#MODELS[@]} -eq 0 ]; then
    echo "  找不到 .gguf 模型，請先執行 01_download_model.sh"
    exit 1
fi

# 顯示模型清單（含大小）
echo ""
CURRENT_MODEL=$(readlink -f "$CURRENT_LINK" 2>/dev/null || echo "")
for i in "${!MODELS[@]}"; do
    SIZE=$(du -h "${MODELS[$i]}" | cut -f1)
    NAME=$(basename "${MODELS[$i]}")
    CURRENT_MARK=""
    [ "${MODELS[$i]}" = "$CURRENT_MODEL" ] && CURRENT_MARK=" ← 目前使用"
    echo "  [$i] $NAME ($SIZE)${CURRENT_MARK}"
done
echo ""

# ── 2. 管理選項 ───────────────────────────────────────────────────────────────
echo "操作選項："
echo "  [s] 切換模型並重啟服務"
echo "  [i] 查看模型資訊"
echo "  [t] 快速測試模型"
echo "  [d] 刪除模型"
echo "  [0] 離開"
echo ""
read -rp "請選擇: " ACTION

case "$ACTION" in
    s|S)
        read -rp "選擇模型編號: " MODEL_IDX
        if [ -z "${MODELS[$MODEL_IDX]}" ]; then
            echo "無效編號"
            exit 1
        fi
        NEW_MODEL="${MODELS[$MODEL_IDX]}"
        echo ""
        echo "切換到：$(basename "$NEW_MODEL")"

        # 更新 symlink
        ln -sf "$NEW_MODEL" "$CURRENT_LINK"

        # 更新 systemd service（如果存在）
        if systemctl list-unit-files llama-server.service &>/dev/null; then
            echo "更新 llama-server 服務設定..."
            sudo sed -i "s|--model [^ ]*|--model ${NEW_MODEL}|" \
                /etc/systemd/system/llama-server.service 2>/dev/null || true
            sudo systemctl daemon-reload
            sudo systemctl restart llama-server
            sleep 3
            echo "✓ 服務已重啟"
            systemctl is-active llama-server && echo "✓ llama-server 運行中" || echo "✗ 服務啟動失敗"
        else
            echo "✓ 模型 symlink 已更新：$CURRENT_LINK → $NEW_MODEL"
            echo "  請手動重啟 llama-server 指定新模型"
        fi

        # 儲存設定
        echo "CURRENT_MODEL=${NEW_MODEL}" > "$CONFIG_FILE"
        ;;

    i|I)
        read -rp "查看模型編號: " MODEL_IDX
        MODEL_PATH="${MODELS[$MODEL_IDX]}"
        echo ""
        echo "模型資訊："
        echo "  路徑：$MODEL_PATH"
        echo "  大小：$(du -h "$MODEL_PATH" | cut -f1)"
        echo "  修改時間：$(stat -c '%y' "$MODEL_PATH" | cut -d. -f1)"
        # 用 llama-cli 讀取模型資訊
        if command -v llama-cli &>/dev/null; then
            echo "  架構資訊："
            llama-cli -m "$MODEL_PATH" --no-warmup -p "" -n 0 --log-disable 2>&1 | \
                grep -E "model|arch|param|layer|embed|head|context" | head -10 | sed 's/^/    /' || true
        fi
        ;;

    t|T)
        read -rp "測試模型編號: " MODEL_IDX
        MODEL_PATH="${MODELS[$MODEL_IDX]}"
        if ! command -v llama-cli &>/dev/null; then
            echo "  llama-cli 不可用"
            exit 1
        fi
        echo ""
        echo "快速測試（生成 20 tokens）："
        time llama-cli -m "$MODEL_PATH" \
            -n 20 -p "Hello, my name is" \
            --n-gpu-layers -1 \
            --log-disable \
            --no-warmup 2>/dev/null | tail -3
        ;;

    d|D)
        read -rp "刪除模型編號: " MODEL_IDX
        MODEL_PATH="${MODELS[$MODEL_IDX]}"
        echo "將刪除：$(basename "$MODEL_PATH")（$(du -h "$MODEL_PATH" | cut -f1)）"
        read -rp "確認刪除？[y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            rm -f "$MODEL_PATH"
            echo "✓ 已刪除"
        fi
        ;;

    *)
        echo "離開"
        ;;
esac

echo ""
echo "=== 完成 ==="
