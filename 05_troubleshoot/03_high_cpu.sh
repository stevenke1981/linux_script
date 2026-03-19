#!/bin/bash
# 03_high_cpu.sh — CPU 負載過高快速診斷
set -e

echo "=== CPU 負載診斷 ==="
echo ""

# ── 1. 系統負載概況 ───────────────────────────────────────────────────────────
echo "[1/5] 系統負載："
echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
CPU_CORES=$(nproc)
echo "  CPU 核心數：$CPU_CORES"
LOAD1=$(uptime | awk -F'[,:]' '{gsub(/ /,"",$NF); print $(NF-2)}' | tr -d ' ')
echo ""

# ── 2. CPU 使用率最高的 Process ───────────────────────────────────────────────
echo "[2/5] CPU 使用率 TOP 15："
ps aux --sort=-%cpu | awk 'NR==1{print "  "$0} NR>1 && NR<=16{printf "  %-12s %5s%% %5s%%  %s\n", $1, $3, $4, $11}' | column -t
echo ""

# ── 3. 找出 D-state 僵屍 process ─────────────────────────────────────────────
echo "[3/5] 僵屍 / 等待 I/O Process："
ZOMBIES=$(ps aux | awk '$8=="Z"{print $2, $11}')
DSTATE=$(ps aux | awk '$8=="D"{print $2, $11}')
if [ -n "$ZOMBIES" ]; then
    echo "  僵屍 Process:"
    echo "$ZOMBIES" | sed 's/^/    /'
else
    echo "  ✓ 無僵屍 Process"
fi
if [ -n "$DSTATE" ]; then
    echo "  D-state (等待 I/O):"
    echo "$DSTATE" | sed 's/^/    /'
else
    echo "  ✓ 無 D-state Process"
fi
echo ""

# ── 4. 系統 CPU 資訊 ──────────────────────────────────────────────────────────
echo "[4/5] CPU 資訊："
echo "  型號：$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "  核心：$CPU_CORES 核"
echo "  目前頻率："
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    for i in $(seq 0 $((CPU_CORES - 1 < 7 ? CPU_CORES - 1 : 7))); do
        FREQ=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
        echo "    CPU$i: $((FREQ/1000)) MHz"
    done
fi
echo ""

# ── 5. 互動式 Kill Process ────────────────────────────────────────────────────
echo "[5/5] 是否要終止特定 Process？"
read -rp "  輸入 PID（多個以空格分隔，直接 Enter 跳過）: " PIDS
if [ -n "$PIDS" ]; then
    for pid in $PIDS; do
        if kill -0 "$pid" 2>/dev/null; then
            PROC_NAME=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            read -rp "  確認終止 PID $pid ($PROC_NAME)？[y/N]: " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                kill -TERM "$pid"
                sleep 1
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid"
                    echo "  ✓ 強制終止 $pid"
                else
                    echo "  ✓ 已終止 $pid ($PROC_NAME)"
                fi
            fi
        else
            echo "  PID $pid 不存在"
        fi
    done
fi

echo ""
echo "=== 診斷完成 ==="
echo "若需持續監控，執行："
echo "  watch -n 1 'ps aux --sort=-%cpu | head -20'"
echo "  htop"
