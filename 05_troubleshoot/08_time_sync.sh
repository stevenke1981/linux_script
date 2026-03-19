#!/bin/bash
# 08_time_sync.sh — 系統時間不同步快速修復
set -e

echo "=== 系統時間同步診斷 ==="
echo ""

# ── 1. 目前時間狀況 ───────────────────────────────────────────────────────────
echo "[1/4] 目前時間狀況："
echo "  系統時間：$(date)"
echo "  硬體時鐘：$(sudo hwclock --show 2>/dev/null || echo '無法讀取')"
echo ""
timedatectl status 2>/dev/null | sed 's/^/  /'
echo ""

# ── 2. NTP 同步狀態 ───────────────────────────────────────────────────────────
echo "[2/4] NTP 同步狀態："
if command -v timedatectl &>/dev/null; then
    NTP_STATUS=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "unknown")
    echo "  NTP 同步：$NTP_STATUS"
    if systemctl is-active systemd-timesyncd &>/dev/null; then
        echo "  timesyncd：執行中"
        timedatectl timesync-status 2>/dev/null | sed 's/^/  /' | head -8 || true
    else
        echo "  timesyncd：未執行"
    fi
fi
echo ""

# ── 3. 修復時間同步 ───────────────────────────────────────────────────────────
echo "[3/4] 修復時間同步..."

# 設定時區（台灣）
read -rp "  設定時區為 Asia/Taipei？[Y/n]: " SET_TZ
SET_TZ="${SET_TZ:-Y}"
if [[ "$SET_TZ" =~ ^[Yy]$ ]]; then
    sudo timedatectl set-timezone Asia/Taipei
    echo "  ✓ 時區已設定：$(timedatectl | grep 'Time zone' | awk '{print $3}')"
fi

# 選擇 NTP 伺服器
echo ""
echo "  NTP 伺服器選項："
echo "  [1] 台灣 NTP（time.stdtime.gov.tw）- 推薦"
echo "  [2] Cloudflare（time.cloudflare.com）"
echo "  [3] Google（time.google.com）"
echo "  [4] 使用預設"
read -rp "  請選擇 [1]: " NTP_OPT
NTP_OPT="${NTP_OPT:-1}"

case "$NTP_OPT" in
    1) NTP_SERVER="time.stdtime.gov.tw" ;;
    2) NTP_SERVER="time.cloudflare.com" ;;
    3) NTP_SERVER="time.google.com" ;;
    *) NTP_SERVER="" ;;
esac

if [ -n "$NTP_SERVER" ]; then
    # 設定 timesyncd
    sudo mkdir -p /etc/systemd/timesyncd.conf.d
    sudo tee /etc/systemd/timesyncd.conf.d/custom.conf > /dev/null <<EOF
[Time]
NTP=$NTP_SERVER
FallbackNTP=pool.ntp.org
EOF
    echo "  ✓ NTP 伺服器設定：$NTP_SERVER"
fi

# 啟用並重啟 timesyncd
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
sleep 3

# 強制立即同步
if command -v chronyc &>/dev/null; then
    sudo chronyc makestep 2>/dev/null || true
fi
echo "  ✓ NTP 同步已啟用"

# ── 4. 最終狀況 ───────────────────────────────────────────────────────────────
echo ""
echo "[4/4] 最終時間狀況："
echo "  系統時間：$(date)"
timedatectl | grep -E "Local time|Time zone|NTP|synchronized" | sed 's/^/  /'

echo ""
echo "=== 完成 ==="
