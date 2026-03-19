#!/bin/bash
# 02_memory_swap.sh — 記憶體不足 / Swap 設定快速處理
set -e

echo "=== 記憶體診斷與 Swap 設定 ==="
echo ""

# ── 1. 目前記憶體狀況 ─────────────────────────────────────────────────────────
echo "[1/5] 記憶體狀況："
free -h
echo ""
echo "記憶體使用最多的 Process TOP 10："
ps aux --sort=-%mem | awk 'NR<=11{printf "  %-10s %5s%% %s\n", $1, $4, $11}' | column -t
echo ""

# ── 2. 清除 Page Cache ────────────────────────────────────────────────────────
echo "[2/5] 清除 Page Cache（無損操作）..."
BEFORE_FREE=$(free -m | awk '/^Mem:/{print $4}')
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
sleep 1
AFTER_FREE=$(free -m | awk '/^Mem:/{print $4}')
FREED=$(( AFTER_FREE - BEFORE_FREE ))
echo "  ✓ 釋放前：${BEFORE_FREE}MB 可用 → 釋放後：${AFTER_FREE}MB 可用（+${FREED}MB）"

# ── 3. 目前 Swap 狀況 ─────────────────────────────────────────────────────────
echo ""
echo "[3/5] Swap 狀況："
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo "  ⚠ 目前沒有 Swap"
    read -rp "  建立 Swap 檔案？[Y/n]: " CREATE_SWAP
    CREATE_SWAP="${CREATE_SWAP:-Y}"
else
    free -h | grep Swap
    echo "  目前 Swap：${SWAP_TOTAL}MB"
    read -rp "  重新建立 Swap？[y/N]: " CREATE_SWAP
fi

# ── 4. 建立 Swap ──────────────────────────────────────────────────────────────
if [[ "$CREATE_SWAP" =~ ^[Yy]$ ]]; then
    echo ""
    echo "[4/5] 建立 Swap 檔案..."
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    SWAP_GB=$(( RAM_GB < 4 ? 4 : RAM_GB ))
    SWAPFILE="/swapfile"

    # 停用現有 swap
    if swapon --show | grep -q "$SWAPFILE"; then
        sudo swapoff "$SWAPFILE" 2>/dev/null || true
    fi

    echo "  建立 ${SWAP_GB}GB Swap（RAM: ${RAM_GB}GB）..."
    sudo fallocate -l "${SWAP_GB}G" "$SWAPFILE"
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
    sudo swapon "$SWAPFILE"

    # 寫入 fstab（持久化）
    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
        echo "  ✓ 已加入 /etc/fstab（開機自動掛載）"
    fi

    # 設定 swappiness
    sudo sysctl vm.swappiness=10 > /dev/null
    grep -q "vm.swappiness" /etc/sysctl.conf || echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "  ✓ Swap ${SWAP_GB}GB 已建立，swappiness=10"
else
    echo ""
    echo "[4/5] 跳過 Swap 建立"
fi

# ── 5. 最終狀況 ───────────────────────────────────────────────────────────────
echo ""
echo "[5/5] 最終記憶體狀況："
free -h

echo ""
echo "=== 完成 ==="
