#!/bin/bash
# 07_auto_restart_service.sh — AI 服務自動重啟守護腳本
# 建立 watchdog：當 API 無回應時自動重啟 llama-server
set -e

echo "=== AI 服務自動重啟 Watchdog ==="
echo ""

WATCHDOG_SCRIPT="/usr/local/bin/ai-watchdog.sh"
WATCHDOG_SERVICE="/etc/systemd/system/ai-watchdog.service"
WATCHDOG_TIMER="/etc/systemd/system/ai-watchdog.timer"

# ── 1. 設定參數 ───────────────────────────────────────────────────────────────
echo "[1/4] 設定參數："
read -rp "  監控的服務名稱 [llama-server]: " TARGET_SERVICE
TARGET_SERVICE="${TARGET_SERVICE:-llama-server}"

read -rp "  API 健康檢查 URL [http://localhost:8080/health]: " HEALTH_URL
HEALTH_URL="${HEALTH_URL:-http://localhost:8080/health}"

read -rp "  失敗幾次後重啟（連續）[3]: " FAIL_THRESHOLD
FAIL_THRESHOLD="${FAIL_THRESHOLD:-3}"

read -rp "  檢查間隔（秒）[30]: " CHECK_INTERVAL
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"

# ── 2. 建立 Watchdog 腳本 ─────────────────────────────────────────────────────
echo ""
echo "[2/4] 建立 Watchdog 腳本..."

sudo tee "$WATCHDOG_SCRIPT" > /dev/null <<EOF
#!/bin/bash
# ai-watchdog.sh — AI 服務健康監控
SERVICE="${TARGET_SERVICE}"
HEALTH_URL="${HEALTH_URL}"
FAIL_THRESHOLD=${FAIL_THRESHOLD}
STATE_FILE="/tmp/ai-watchdog-fails"

# 讀取失敗次數
FAILS=\$(cat "\$STATE_FILE" 2>/dev/null || echo 0)

# 健康檢查
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "\$HEALTH_URL" 2>/dev/null || echo "000")

if [ "\$HTTP_CODE" = "200" ]; then
    echo 0 > "\$STATE_FILE"
    echo "\$(date '+%H:%M:%S') [\$SERVICE] 健康檢查通過 ✓"
    exit 0
fi

# 失敗計數
FAILS=\$(( FAILS + 1 ))
echo \$FAILS > "\$STATE_FILE"
echo "\$(date '+%H:%M:%S') [\$SERVICE] 健康檢查失敗 ✗ (HTTP \$HTTP_CODE, 第 \${FAILS} 次)"

if [ "\$FAILS" -ge "\$FAIL_THRESHOLD" ]; then
    echo "\$(date '+%H:%M:%S') [\$SERVICE] 達到失敗閾值（\$FAIL_THRESHOLD 次），重啟服務..."
    systemctl restart "\$SERVICE"
    echo 0 > "\$STATE_FILE"

    # 記錄重啟事件
    echo "\$(date) 服務重啟：\$SERVICE（HTTP \$HTTP_CODE）" >> /var/log/ai-watchdog.log
    echo "\$(date '+%H:%M:%S') [\$SERVICE] 重啟完成"
fi
EOF

sudo chmod +x "$WATCHDOG_SCRIPT"
echo "  ✓ Watchdog 腳本：$WATCHDOG_SCRIPT"

# ── 3. 建立 Systemd Timer ─────────────────────────────────────────────────────
echo ""
echo "[3/4] 建立 Systemd Timer..."

sudo tee "$WATCHDOG_SERVICE" > /dev/null <<EOF
[Unit]
Description=AI Service Watchdog
After=network.target

[Service]
Type=oneshot
ExecStart=${WATCHDOG_SCRIPT}
StandardOutput=journal
StandardError=journal
EOF

sudo tee "$WATCHDOG_TIMER" > /dev/null <<EOF
[Unit]
Description=AI Watchdog Timer

[Timer]
OnBootSec=60
OnUnitActiveSec=${CHECK_INTERVAL}s
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ai-watchdog.timer
sudo systemctl start ai-watchdog.timer

echo "  ✓ Watchdog Timer 已啟動（每 ${CHECK_INTERVAL}s 檢查）"

# ── 4. 確認狀態 ───────────────────────────────────────────────────────────────
echo ""
echo "[4/4] Watchdog 狀態："
systemctl status ai-watchdog.timer --no-pager | head -10

echo ""
echo "=== 完成 ==="
echo ""
echo "Watchdog 設定："
echo "  監控服務：$TARGET_SERVICE"
echo "  健康 URL：$HEALTH_URL"
echo "  失敗閾值：$FAIL_THRESHOLD 次"
echo "  檢查間隔：${CHECK_INTERVAL}s"
echo "  日誌：/var/log/ai-watchdog.log"
echo ""
echo "管理指令："
echo "  sudo systemctl stop/start ai-watchdog.timer"
echo "  journalctl -u ai-watchdog -f"
echo "  cat /var/log/ai-watchdog.log"
