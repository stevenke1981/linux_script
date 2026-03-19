#!/bin/bash
# 07_log_cleanup.sh — 日誌檔管理與清理
set -e

echo "=== 日誌檔診斷與清理 ==="
echo ""

# ── 1. 日誌佔用空間分析 ───────────────────────────────────────────────────────
echo "[1/5] 日誌空間使用："
echo "  /var/log 總計："
du -sh /var/log 2>/dev/null
echo ""
echo "  最大日誌檔 TOP 10："
sudo find /var/log -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -10 | \
    awk '{printf "  %6.1f MB  %s\n", $1/1024/1024, $2}'
echo ""

# ── 2. journald 狀態 ──────────────────────────────────────────────────────────
echo "[2/5] Journald 日誌佔用："
journalctl --disk-usage 2>/dev/null
echo ""

# ── 3. 清理選項 ───────────────────────────────────────────────────────────────
echo "[3/5] 清理選項："
echo "  [1] 保留最近 7 天日誌（推薦）"
echo "  [2] 保留最近 3 天日誌"
echo "  [3] 限制 journald 大小為 500MB"
echo "  [4] 清除所有壓縮日誌 (.gz / .1)"
echo "  [5] 全部執行（1+3+4）"
echo "  [0] 跳過"
echo ""
read -rp "  請選擇: " CLEAN_OPT

do_journal_7d() {
    sudo journalctl --vacuum-time=7d
    sudo journalctl --vacuum-size=1G
    echo "  ✓ journald 保留 7 天"
}
do_journal_3d() {
    sudo journalctl --vacuum-time=3d
    sudo journalctl --vacuum-size=500M
    echo "  ✓ journald 保留 3 天"
}
do_journal_size() {
    sudo journalctl --vacuum-size=500M
    # 持久化設定
    sudo mkdir -p /etc/systemd/journald.conf.d
    sudo tee /etc/systemd/journald.conf.d/size-limit.conf > /dev/null <<EOF
[Journal]
SystemMaxUse=500M
SystemKeepFree=100M
MaxRetentionSec=2week
EOF
    sudo systemctl restart systemd-journald
    echo "  ✓ journald 上限設為 500MB（持久化）"
}
do_gz_cleanup() {
    COUNT=$(sudo find /var/log -name "*.gz" -o -name "*.1" 2>/dev/null | wc -l)
    sudo find /var/log -name "*.gz" -delete 2>/dev/null || true
    sudo find /var/log -name "*.1" -delete  2>/dev/null || true
    echo "  ✓ 已刪除 $COUNT 個舊日誌壓縮檔"
}

case "$CLEAN_OPT" in
    1) do_journal_7d ;;
    2) do_journal_3d ;;
    3) do_journal_size ;;
    4) do_gz_cleanup ;;
    5) do_journal_7d; do_journal_size; do_gz_cleanup ;;
    *) echo "  跳過清理" ;;
esac
echo ""

# ── 4. 設定 logrotate 自動輪替 ────────────────────────────────────────────────
echo "[4/5] 設定自動 logrotate..."
read -rp "  設定 logrotate 每日壓縮保留 14 天？[Y/n]: " SET_ROTATE
SET_ROTATE="${SET_ROTATE:-Y}"
if [[ "$SET_ROTATE" =~ ^[Yy]$ ]]; then
    sudo tee /etc/logrotate.d/custom-server > /dev/null <<'EOF'
/var/log/syslog
/var/log/kern.log
/var/log/auth.log
{
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
}
EOF
    echo "  ✓ logrotate 已設定：每日輪替，保留 14 天"
fi
echo ""

# ── 5. 最終狀況 ───────────────────────────────────────────────────────────────
echo "[5/5] 清理後狀況："
du -sh /var/log 2>/dev/null
journalctl --disk-usage 2>/dev/null

echo ""
echo "=== 完成 ==="
