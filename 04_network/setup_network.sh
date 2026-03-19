#!/bin/bash
# setup_network.sh
# Ubuntu 網路介面與區域網路設定
# 支援：靜態 IP / DHCP 切換、DNS 設定、Netplan (Ubuntu 18.04+)
# 用法：bash setup_network.sh
set -e

echo "=== 網路介面設定 ==="
echo ""

# ── 0. 偵測目前網路介面 ────────────────────────────────────────────────────────
echo "[0] 目前網路介面狀態："
echo "────────────────────────────────"
ip -br addr show
echo "────────────────────────────────"
echo ""

# 列出可用的實體網路介面（排除 lo / virtual）
INTERFACES=()
while IFS= read -r iface; do
    INTERFACES+=("$iface")
done < <(ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^lo$|^vir|^docker|^br-|^veth|^tun|^tap')

if [ ${#INTERFACES[@]} -eq 0 ]; then
    echo "錯誤：找不到可設定的網路介面"
    exit 1
fi

# ── 1. 選擇介面 ────────────────────────────────────────────────────────────────
echo "可設定的網路介面："
for i in "${!INTERFACES[@]}"; do
    echo "  [$i] ${INTERFACES[$i]}"
done
echo ""
read -rp "請選擇介面編號 [預設 0]: " IFACE_IDX
IFACE_IDX="${IFACE_IDX:-0}"
IFACE="${INTERFACES[$IFACE_IDX]}"
echo "已選擇介面：$IFACE"
echo ""

# ── 2. 選擇設定模式 ────────────────────────────────────────────────────────────
echo "設定模式："
echo "  [1] 靜態 IP（手動指定）"
echo "  [2] DHCP（自動取得）"
echo ""
read -rp "請選擇 [預設 1]: " MODE
MODE="${MODE:-1}"

# ── 3. 收集靜態 IP 參數 ────────────────────────────────────────────────────────
if [ "$MODE" = "1" ]; then
    echo ""
    echo "=== 靜態 IP 設定 ==="

    # 顯示目前值作為參考
    CURRENT_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
    CURRENT_GW=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
    [ -n "$CURRENT_IP" ] && echo "目前 IP：$CURRENT_IP"
    [ -n "$CURRENT_GW" ] && echo "目前閘道：$CURRENT_GW"
    echo ""

    read -rp "IP 位址（含遮罩，例如 192.168.1.100/24）: " STATIC_IP
    read -rp "預設閘道（例如 192.168.1.1）: " GATEWAY
    read -rp "主要 DNS（預設 1.1.1.1）: " DNS1
    DNS1="${DNS1:-1.1.1.1}"
    read -rp "次要 DNS（預設 8.8.8.8）: " DNS2
    DNS2="${DNS2:-8.8.8.8}"

    if [ -z "$STATIC_IP" ] || [ -z "$GATEWAY" ]; then
        echo "錯誤：IP 與閘道不能為空"
        exit 1
    fi
fi

# ── 4. 偵測 Netplan 設定檔 ─────────────────────────────────────────────────────
echo ""
echo "[1/3] 設定 Netplan..."

NETPLAN_DIR="/etc/netplan"
if [ ! -d "$NETPLAN_DIR" ]; then
    echo "錯誤：找不到 /etc/netplan，此系統可能不支援 Netplan"
    echo "請改用 /etc/network/interfaces 手動設定"
    exit 1
fi

# 備份現有設定
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NETPLAN_FILE="$NETPLAN_DIR/99-custom-${IFACE}.yaml"
if ls "$NETPLAN_DIR"/*.yaml &>/dev/null; then
    sudo cp "$NETPLAN_DIR" "$NETPLAN_DIR.bak.$TIMESTAMP" -r 2>/dev/null || true
    echo "  已備份原始設定 → $NETPLAN_DIR.bak.$TIMESTAMP"
fi

# ── 5. 寫入 Netplan 設定 ───────────────────────────────────────────────────────
if [ "$MODE" = "1" ]; then
    sudo tee "$NETPLAN_FILE" > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses:
        - ${STATIC_IP}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS1}
          - ${DNS2}
EOF
    echo "  已寫入靜態 IP 設定 → $NETPLAN_FILE"
else
    sudo tee "$NETPLAN_FILE" > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: yes
      dhcp6: no
EOF
    echo "  已寫入 DHCP 設定 → $NETPLAN_FILE"
fi

# 修正權限（Netplan 要求 600）
sudo chmod 600 "$NETPLAN_FILE"

# ── 6. 套用設定 ────────────────────────────────────────────────────────────────
echo ""
echo "[2/3] 套用 Netplan 設定..."
sudo netplan generate 2>&1 | grep -v "^$" || true
sudo netplan apply

echo "  設定已套用"

# ── 7. 驗證連線 ────────────────────────────────────────────────────────────────
echo ""
echo "[3/3] 驗證網路連線..."
sleep 2

echo ""
echo "介面狀態："
ip -br addr show "$IFACE"

echo ""
echo "路由表："
ip route show | grep -E "default|$IFACE"

echo ""
echo "DNS 設定："
if [ -f /etc/resolv.conf ]; then
    grep "nameserver" /etc/resolv.conf | head -3
fi

echo ""
echo "連線測試（ping 8.8.8.8）："
if ping -c 3 -W 3 8.8.8.8 &>/dev/null; then
    echo "  ✓ 網際網路連線正常"
else
    echo "  ✗ 無法連線至 8.8.8.8，請確認閘道設定"
fi

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== 設定完成 ==="
echo ""
echo "介面：$IFACE"
if [ "$MODE" = "1" ]; then
    echo "模式：靜態 IP"
    echo "IP：$STATIC_IP"
    echo "閘道：$GATEWAY"
    echo "DNS：$DNS1, $DNS2"
else
    echo "模式：DHCP（自動取得）"
fi
echo ""
echo "設定檔：$NETPLAN_FILE"
echo ""
echo "還原設定："
echo "  sudo rm $NETPLAN_FILE && sudo netplan apply"
