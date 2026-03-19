#!/bin/bash
# 05_network_debug.sh — 網路連線問題快速診斷
set -e

echo "=== 網路連線診斷 ==="
echo ""

# ── 1. 介面狀態 ───────────────────────────────────────────────────────────────
echo "[1/6] 網路介面狀態："
ip -br addr show
echo ""
echo "連線狀態："
ip link show | grep -E "state (UP|DOWN|UNKNOWN)" | awk '{print "  "$2, $9}' | tr -d ':'
echo ""

# ── 2. 路由表 ─────────────────────────────────────────────────────────────────
echo "[2/6] 路由表："
ip route show
echo ""

# ── 3. DNS 解析測試 ───────────────────────────────────────────────────────────
echo "[3/6] DNS 解析測試："
DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
echo "  設定的 DNS："
echo "$DNS_SERVERS" | sed 's/^/    /'
echo ""
echo "  解析測試（google.com）："
if nslookup google.com 2>/dev/null | grep -q "Address"; then
    echo "  ✓ DNS 解析正常"
    nslookup google.com 2>/dev/null | grep "Address" | tail -1
else
    echo "  ✗ DNS 解析失敗"
    echo "  嘗試修復 DNS（使用 1.1.1.1）..."
    echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "  ✓ 已設定備用 DNS"
fi
echo ""

# ── 4. 連線測試 ───────────────────────────────────────────────────────────────
echo "[4/6] 連線測試："
declare -A TARGETS=(
    ["閘道"]="$(ip route | awk '/default/{print $3}' | head -1)"
    ["Cloudflare DNS"]="1.1.1.1"
    ["Google DNS"]="8.8.8.8"
    ["Google"]="google.com"
)

for NAME in "閘道" "Cloudflare DNS" "Google DNS" "Google"; do
    TARGET="${TARGETS[$NAME]}"
    if [ -z "$TARGET" ]; then continue; fi
    if ping -c 1 -W 2 "$TARGET" &>/dev/null; then
        LATENCY=$(ping -c 1 -W 2 "$TARGET" | grep time= | awk -F'time=' '{print $2}' | cut -d' ' -f1)
        echo "  ✓ $NAME ($TARGET) — ${LATENCY}ms"
    else
        echo "  ✗ $NAME ($TARGET) — 無法連線"
    fi
done
echo ""

# ── 5. 開放的 Port 與防火牆 ───────────────────────────────────────────────────
echo "[5/6] 防火牆狀態："
if command -v ufw &>/dev/null; then
    sudo ufw status | head -20
else
    echo "  ufw 未安裝"
fi
echo ""
echo "監聽中的 Port（TCP）："
ss -tlnp | grep LISTEN | awk '{printf "  %-25s %s\n", $4, $6}' | head -15
echo ""

# ── 6. 常見修復 ───────────────────────────────────────────────────────────────
echo "[6/6] 快速修復選項："
echo "  [1] 重啟網路服務（NetworkManager）"
echo "  [2] 重啟網路服務（systemd-networkd）"
echo "  [3] 重新套用 Netplan"
echo "  [4] 釋放並重新取得 DHCP"
echo "  [0] 跳過"
echo ""
read -rp "  請選擇: " FIX

case "$FIX" in
    1)
        sudo systemctl restart NetworkManager
        sleep 2
        echo "  ✓ NetworkManager 已重啟"
        ip -br addr show
        ;;
    2)
        sudo systemctl restart systemd-networkd
        sleep 2
        echo "  ✓ systemd-networkd 已重啟"
        ;;
    3)
        sudo netplan apply
        echo "  ✓ Netplan 已重新套用"
        ;;
    4)
        IFACE=$(ip route | awk '/default/{print $5}' | head -1)
        sudo dhclient -r "$IFACE" 2>/dev/null || true
        sudo dhclient "$IFACE" 2>/dev/null
        echo "  ✓ DHCP 已重新取得"
        ip -br addr show "$IFACE"
        ;;
    *)
        echo "  跳過修復"
        ;;
esac

echo ""
echo "=== 診斷完成 ==="
