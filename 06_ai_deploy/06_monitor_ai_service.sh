#!/bin/bash
# 06_monitor_ai_service.sh — AI 服務即時監控儀表板
# 用法：bash 06_monitor_ai_service.sh [interval_seconds]

INTERVAL="${1:-5}"
API_BASE="${API_BASE:-http://localhost:8080}"

# 清除終端
clear_screen() { printf '\033[2J\033[H'; }

# 顏色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_dashboard() {
    clear_screen
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║          AI 服務監控儀表板  $(date '+%Y-%m-%d %H:%M:%S')          ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # ── 系統資源 ──────────────────────────────────────────────────────────
    echo -e "${CYAN}【系統資源】${RESET}"
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    MEM_INFO=$(free -h | awk '/^Mem:/{print $3"/"$2}')
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo "  CPU: ${CPU_USAGE}%  |  RAM: ${MEM_INFO}  |  Load: ${LOAD}"
    echo ""

    # ── GPU 狀態 ──────────────────────────────────────────────────────────
    echo -e "${CYAN}【GPU 狀態】${RESET}"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw \
            --format=csv,noheader | while IFS=',' read -r idx name mused mtotal util temp power; do
            pct=$(echo "$mused $mtotal" | awk '{gsub(/[^0-9]/,"",$1); gsub(/[^0-9]/,"",$2); if($2>0) printf "%d", $1*100/$2; else print 0}')
            COLOR="$GREEN"
            [ "$pct" -gt 80 ] 2>/dev/null && COLOR="$YELLOW"
            [ "$pct" -gt 95 ] 2>/dev/null && COLOR="$RED"
            echo -e "  GPU${idx}: ${name} | VRAM: ${COLOR}${mused}/${mtotal} (${pct}%)${RESET} | ${util} | ${temp}°C | ${power}"
        done
    else
        echo "  GPU 不可用"
    fi
    echo ""

    # ── AI 服務狀態 ───────────────────────────────────────────────────────
    echo -e "${CYAN}【AI 服務狀態】${RESET}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "${API_BASE}/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "  llama-server: ${GREEN}✓ 運行中${RESET} (${API_BASE})"
    else
        echo -e "  llama-server: ${RED}✗ 無法連線${RESET} ($HTTP_CODE)"
    fi

    # Systemd 服務狀態
    for svc in llama-server ollama; do
        if systemctl is-active "$svc" &>/dev/null 2>&1; then
            UPTIME=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null | cut -d' ' -f2-3)
            echo -e "  ${svc}: ${GREEN}active${RESET} (since ${UPTIME})"
        elif systemctl list-unit-files "$svc.service" &>/dev/null 2>&1; then
            echo -e "  ${svc}: ${RED}inactive${RESET}"
        fi
    done
    echo ""

    # ── GPU Process ───────────────────────────────────────────────────────
    echo -e "${CYAN}【GPU Process】${RESET}"
    if command -v nvidia-smi &>/dev/null; then
        GPU_PROCS=$(nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null)
        if [ -n "$GPU_PROCS" ]; then
            echo "$GPU_PROCS" | awk -F',' '{printf "  PID %-8s VRAM %-10s %s\n", $1, $2, $3}'
        else
            echo "  無 Process 使用 GPU"
        fi
    fi
    echo ""

    # ── 最近日誌 ──────────────────────────────────────────────────────────
    echo -e "${CYAN}【llama-server 最近日誌】${RESET}"
    journalctl -u llama-server -n 5 --no-pager 2>/dev/null | grep -v "^-- " | \
        awk '{print "  "$0}' | tail -5 || echo "  無日誌（服務未用 systemd 啟動）"
    echo ""

    echo -e "${BOLD}更新間隔：${INTERVAL}s  |  按 Ctrl+C 結束${RESET}"
}

# 主迴圈
trap 'echo ""; echo "監控已停止"; exit 0' INT
while true; do
    print_dashboard
    sleep "$INTERVAL"
done
