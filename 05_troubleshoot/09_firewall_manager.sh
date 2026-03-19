#!/bin/bash
# 09_firewall_manager.sh — 防火牆快速管理（UFW）
set -e

echo "=== 防火牆管理（UFW）==="
echo ""

# ── 安裝 UFW（若未安裝）──────────────────────────────────────────────────────
if ! command -v ufw &>/dev/null; then
    echo "UFW 未安裝，正在安裝..."
    sudo apt-get install -y ufw
fi

# ── 1. 目前狀態 ───────────────────────────────────────────────────────────────
echo "[1/3] 目前防火牆規則："
sudo ufw status verbose 2>/dev/null | head -30
echo ""

# ── 2. 目前監聽 Port ──────────────────────────────────────────────────────────
echo "[2/3] 目前系統監聽 Port："
ss -tlnp | grep LISTEN | awk '{printf "  %-25s %s\n", $4, $6}' | head -15
echo ""

# ── 3. 管理選單 ───────────────────────────────────────────────────────────────
echo "[3/3] 管理選項："
echo "  [1]  啟用防火牆（預設拒絕入站，允許出站）"
echo "  [2]  停用防火牆"
echo "  [3]  開放 Port"
echo "  [4]  關閉 Port"
echo "  [5]  開放常用服務（SSH/HTTP/HTTPS/XRDP）"
echo "  [6]  僅允許特定 IP 連線"
echo "  [7]  查看目前規則"
echo "  [8]  刪除規則"
echo "  [0]  離開"
echo ""
read -rp "  請選擇: " OPT

case "$OPT" in
    1)
        # 先確保 SSH 不被鎖住
        sudo ufw allow ssh
        sudo ufw --force enable
        echo "  ✓ 防火牆已啟用"
        ;;
    2)
        sudo ufw --force disable
        echo "  ✓ 防火牆已停用"
        ;;
    3)
        read -rp "  開放 Port（例如 8080 或 8080/tcp）: " PORT
        sudo ufw allow "$PORT"
        echo "  ✓ 已開放 $PORT"
        ;;
    4)
        read -rp "  關閉 Port（例如 8080 或 8080/tcp）: " PORT
        sudo ufw deny "$PORT"
        echo "  ✓ 已封鎖 $PORT"
        ;;
    5)
        echo "  開放常用服務..."
        sudo ufw allow ssh     && echo "  ✓ SSH (22)"
        sudo ufw allow 80/tcp  && echo "  ✓ HTTP (80)"
        sudo ufw allow 443/tcp && echo "  ✓ HTTPS (443)"
        sudo ufw allow 3389/tcp && echo "  ✓ XRDP (3389)"
        ;;
    6)
        read -rp "  允許的 IP 或網段（例如 192.168.1.0/24）: " ALLOWED_IP
        read -rp "  目標 Port（留空=所有）: " TARGET_PORT
        if [ -n "$TARGET_PORT" ]; then
            sudo ufw allow from "$ALLOWED_IP" to any port "$TARGET_PORT"
        else
            sudo ufw allow from "$ALLOWED_IP"
        fi
        echo "  ✓ 已允許 $ALLOWED_IP"
        ;;
    7)
        sudo ufw status numbered
        ;;
    8)
        sudo ufw status numbered
        echo ""
        read -rp "  輸入要刪除的規則編號: " RULE_NUM
        sudo ufw delete "$RULE_NUM"
        echo "  ✓ 規則已刪除"
        ;;
    *)
        echo "  離開"
        ;;
esac

echo ""
echo "最終狀態："
sudo ufw status | head -5
