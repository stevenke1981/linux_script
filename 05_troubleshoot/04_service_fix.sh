#!/bin/bash
# 04_service_fix.sh — systemd 服務無法啟動快速修復
set -e

echo "=== Systemd 服務診斷與修復 ==="
echo ""

# ── 1. 列出失敗的服務 ─────────────────────────────────────────────────────────
echo "[1/4] 失敗的服務："
FAILED=$(systemctl list-units --state=failed --no-legend 2>/dev/null | awk '{print $1}')
if [ -z "$FAILED" ]; then
    echo "  ✓ 目前沒有失敗的服務"
else
    echo "$FAILED" | sed 's/^/  ✗ /'
fi
echo ""

# ── 2. 選擇要診斷的服務 ───────────────────────────────────────────────────────
echo "[2/4] 輸入要診斷的服務名稱（例如：nginx、mysql、xrdp）"
read -rp "  服務名稱: " SERVICE
SERVICE="${SERVICE%.service}"

if [ -z "$SERVICE" ]; then
    echo "  未輸入服務名稱，顯示所有服務狀態"
    systemctl list-units --type=service --state=running | head -20
    exit 0
fi

echo ""
echo "── 服務狀態 ──────────────────────────────────────────────────────────"
systemctl status "$SERVICE" --no-pager -l 2>&1 | head -30
echo "──────────────────────────────────────────────────────────────────────"
echo ""

# ── 3. 最近日誌 ───────────────────────────────────────────────────────────────
echo "[3/4] 最近 50 行日誌："
journalctl -u "$SERVICE" -n 50 --no-pager 2>&1 | tail -30
echo ""

# ── 4. 修復選項 ───────────────────────────────────────────────────────────────
echo "[4/4] 修復選項："
echo "  [1] 重啟服務"
echo "  [2] 重新載入設定（reload）"
echo "  [3] 重置失敗狀態後重啟"
echo "  [4] 啟用開機自啟"
echo "  [5] 停用開機自啟"
echo "  [0] 跳過"
echo ""
read -rp "  請選擇 [0-5]: " ACTION

case "$ACTION" in
    1)
        sudo systemctl restart "$SERVICE"
        echo "  ✓ 已重啟 $SERVICE"
        ;;
    2)
        sudo systemctl reload "$SERVICE" 2>/dev/null || sudo systemctl restart "$SERVICE"
        echo "  ✓ 已重新載入 $SERVICE"
        ;;
    3)
        sudo systemctl reset-failed "$SERVICE"
        sudo systemctl start "$SERVICE"
        echo "  ✓ 已重置並啟動 $SERVICE"
        ;;
    4)
        sudo systemctl enable "$SERVICE"
        sudo systemctl start "$SERVICE"
        echo "  ✓ 已啟用開機自啟並啟動 $SERVICE"
        ;;
    5)
        sudo systemctl disable "$SERVICE"
        echo "  ✓ 已停用開機自啟"
        ;;
    *)
        echo "  跳過修復"
        ;;
esac

echo ""
echo "最終狀態："
systemctl is-active "$SERVICE" && echo "  ✓ $SERVICE 正在執行" || echo "  ✗ $SERVICE 未執行"
