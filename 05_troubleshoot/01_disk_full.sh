#!/bin/bash
# 01_disk_full.sh — 磁碟空間不足快速處理
set -e

echo "=== 磁碟空間診斷與清理 ==="
echo ""

# ── 1. 顯示磁碟使用狀況 ───────────────────────────────────────────────────────
echo "[1/6] 磁碟使用狀況："
df -hT | grep -E "Filesystem|/dev/"
echo ""

# ── 2. 找出最大目錄（前10）────────────────────────────────────────────────────
echo "[2/6] 最大目錄 TOP 10（/ 下層）："
sudo du -hx --max-depth=3 / 2>/dev/null | sort -rh | head -10
echo ""

# ── 3. 清理 apt 快取 ──────────────────────────────────────────────────────────
echo "[3/6] 清理 apt 快取..."
BEFORE=$(df / | awk 'NR==2{print $3}')
sudo apt-get clean
sudo apt-get autoremove -y 2>/dev/null || true
AFTER=$(df / | awk 'NR==2{print $3}')
FREED=$(( (BEFORE - AFTER) / 1024 ))
echo "  ✓ 釋放 apt 快取：${FREED} MB"

# ── 4. 清理舊 kernel ──────────────────────────────────────────────────────────
echo ""
echo "[4/6] 清理舊版 kernel..."
CURRENT_KERNEL=$(uname -r)
echo "  目前 kernel：$CURRENT_KERNEL"
OLD_KERNELS=$(dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print $2}' | grep -v "$CURRENT_KERNEL" | grep -v "linux-image-generic" || true)
if [ -n "$OLD_KERNELS" ]; then
    echo "  找到舊 kernel："
    echo "$OLD_KERNELS" | sed 's/^/    /'
    read -rp "  確認移除？[y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "$OLD_KERNELS" | xargs sudo apt-get remove -y
        echo "  ✓ 舊 kernel 已移除"
    fi
else
    echo "  無舊 kernel 需要清理"
fi

# ── 5. 清理大型日誌 ───────────────────────────────────────────────────────────
echo ""
echo "[5/6] 清理 journald 日誌（保留近 7 天）..."
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=500M

# 清理 /var/log 下的大型 .gz 壓縮日誌
echo "  清理 /var/log 舊壓縮日誌..."
sudo find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
sudo find /var/log -name "*.1" -mtime +7 -delete 2>/dev/null || true

# ── 6. 找出大型檔案（>100MB）─────────────────────────────────────────────────
echo ""
echo "[6/6] 大型檔案（>100MB）："
sudo find / -xdev -size +100M -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -10 | \
    awk '{printf "  %6d MB  %s\n", $1/1024/1024, $2}'

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== 清理後磁碟狀況 ==="
df -hT | grep -E "Filesystem|/dev/"
echo ""
echo "若仍不足，手動確認大型檔案後刪除："
echo "  sudo rm -rf /path/to/file"
