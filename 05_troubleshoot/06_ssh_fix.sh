#!/bin/bash
# 06_ssh_fix.sh — SSH 無法連線快速修復
# 注意：在本機執行，修復後可讓遠端恢復連線
set -e

echo "=== SSH 服務診斷與修復 ==="
echo ""

# ── 1. SSH 服務狀態 ───────────────────────────────────────────────────────────
echo "[1/5] SSH 服務狀態："
systemctl status sshd --no-pager 2>/dev/null | head -10 || \
systemctl status ssh  --no-pager 2>/dev/null | head -10 || \
echo "  ⚠ SSH 服務未找到"
echo ""

# ── 2. SSH 設定檔檢查 ─────────────────────────────────────────────────────────
echo "[2/5] SSH 設定檔語法檢查："
if sudo sshd -t 2>&1; then
    echo "  ✓ 設定檔語法正確"
else
    echo "  ✗ 設定檔有錯誤，請修復後重啟"
    echo "  設定檔位置：/etc/ssh/sshd_config"
fi
echo ""

# ── 3. 關鍵設定摘要 ───────────────────────────────────────────────────────────
echo "[3/5] SSH 關鍵設定："
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    PORT=$(grep -E "^Port" "$SSHD_CONFIG" | awk '{print $2}' || echo "22（預設）")
    PERMIT_ROOT=$(grep -E "^PermitRootLogin" "$SSHD_CONFIG" | awk '{print $2}' || echo "未設定（預設 prohibit-password）")
    PUBKEY=$(grep -E "^PubkeyAuthentication" "$SSHD_CONFIG" | awk '{print $2}' || echo "未設定（預設 yes）")
    PASS_AUTH=$(grep -E "^PasswordAuthentication" "$SSHD_CONFIG" | awk '{print $2}' || echo "未設定")
    echo "  Port：$PORT"
    echo "  PermitRootLogin：$PERMIT_ROOT"
    echo "  PubkeyAuthentication：$PUBKEY"
    echo "  PasswordAuthentication：$PASS_AUTH"
fi
echo ""

# ── 4. 防火牆 SSH Port 檢查 ───────────────────────────────────────────────────
echo "[4/5] 防火牆 SSH Port 狀態："
SSH_PORT=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
echo "  SSH Port：$SSH_PORT"
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status | grep -E "$SSH_PORT|ssh" || echo "  未設定規則")
    echo "  ufw 規則：$UFW_STATUS"
fi

# 確保 SSH port 開放
if command -v ufw &>/dev/null && sudo ufw status | grep -q "active"; then
    if ! sudo ufw status | grep -qE "^$SSH_PORT|^OpenSSH|^22"; then
        echo "  ⚠ SSH Port 未在 ufw 規則中，自動開放..."
        sudo ufw allow "$SSH_PORT/tcp"
        echo "  ✓ 已開放 port $SSH_PORT"
    else
        echo "  ✓ ufw 已開放 SSH"
    fi
fi
echo ""

# ── 5. 修復選項 ───────────────────────────────────────────────────────────────
echo "[5/5] 修復選項："
echo "  [1] 重啟 SSH 服務"
echo "  [2] 啟用 PasswordAuthentication（允許密碼登入）"
echo "  [3] 重新產生 SSH Host Keys"
echo "  [4] 開放防火牆 SSH Port"
echo "  [0] 跳過"
echo ""
read -rp "  請選擇: " ACTION

case "$ACTION" in
    1)
        sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh
        echo "  ✓ SSH 服務已重啟"
        ;;
    2)
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh
        echo "  ✓ 已啟用密碼登入並重啟 SSH"
        ;;
    3)
        echo "  重新產生 Host Keys..."
        sudo rm -f /etc/ssh/ssh_host_*
        sudo ssh-keygen -A
        sudo systemctl restart sshd 2>/dev/null || sudo systemctl restart ssh
        echo "  ✓ Host Keys 已重新產生"
        ;;
    4)
        SSH_PORT=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
        sudo ufw allow "$SSH_PORT/tcp" 2>/dev/null || true
        echo "  ✓ 已開放 port $SSH_PORT"
        ;;
    *)
        echo "  跳過"
        ;;
esac

echo ""
echo "=== 完成 ==="
IP=$(hostname -I | awk '{print $1}')
SSH_PORT=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
echo "連線資訊：ssh user@$IP -p $SSH_PORT"
