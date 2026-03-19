#!/bin/bash
# 09_log_collector.sh — AI 服務日誌收集與分析
set -e

echo "=== AI 服務日誌收集與分析 ==="
echo ""

LOG_DIR="${AI_LOG_DIR:-$HOME/ai_logs}"
REPORT_FILE="$LOG_DIR/report_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$LOG_DIR"

# ── 1. 選擇模式 ───────────────────────────────────────────────────────────────
echo "模式："
echo "  [1] 即時跟蹤日誌（tail -f）"
echo "  [2] 產生診斷報告"
echo "  [3] 分析錯誤模式"
echo "  [4] 設定集中日誌（rsyslog）"
echo ""
read -rp "請選擇 [2]: " MODE
MODE="${MODE:-2}"

case "$MODE" in

# ── 即時日誌 ──────────────────────────────────────────────────────────────────
1)
    echo ""
    echo "服務："
    echo "  [1] llama-server"
    echo "  [2] all AI 相關（llama + uvicorn + python）"
    read -rp "請選擇 [1]: " SVC_OPT
    case "${SVC_OPT:-1}" in
        1) journalctl -u llama-server -f --no-pager ;;
        2) journalctl -f --no-pager | grep -E "llama|uvicorn|python.*serve|ai-watchdog" ;;
    esac
    ;;

# ── 診斷報告 ──────────────────────────────────────────────────────────────────
2)
    echo ""
    echo "產生診斷報告 → $REPORT_FILE"
    {
        echo "AI 服務診斷報告"
        echo "產生時間：$(date)"
        echo "主機名稱：$(hostname)"
        echo "=========================================="
        echo ""

        echo "【系統資訊】"
        uname -a
        echo "CPU: $(nproc) cores | RAM: $(free -h | awk '/^Mem:/{print $2}')"
        echo ""

        echo "【GPU 狀態】"
        if command -v nvidia-smi &>/dev/null; then
            nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total,temperature.gpu \
                --format=csv 2>/dev/null
        else
            echo "N/A"
        fi
        echo ""

        echo "【AI 相關服務狀態】"
        for svc in llama-server ai-watchdog; do
            systemctl status "$svc" --no-pager 2>/dev/null | head -5 || echo "$svc: 未安裝"
            echo "---"
        done
        echo ""

        echo "【llama-server 最近 100 行日誌】"
        journalctl -u llama-server -n 100 --no-pager 2>/dev/null || echo "無日誌"
        echo ""

        echo "【錯誤摘要（最近 24 小時）】"
        journalctl -u llama-server --since "24 hours ago" --no-pager 2>/dev/null | \
            grep -iE "error|fail|warn|oom|killed" | tail -30 || echo "無錯誤"
        echo ""

        echo "【磁碟狀況】"
        df -h
        echo ""

        echo "【模型目錄】"
        ls -lh "$HOME/models"/*.gguf 2>/dev/null || echo "無模型檔案"

    } | tee "$REPORT_FILE"

    echo ""
    echo "✓ 報告已儲存：$REPORT_FILE"
    ;;

# ── 錯誤分析 ──────────────────────────────────────────────────────────────────
3)
    echo ""
    echo "【錯誤分析 — 最近 7 天】"
    echo ""

    echo "─ OOM / CUDA 錯誤 ─"
    journalctl -u llama-server --since "7 days ago" --no-pager 2>/dev/null | \
        grep -iE "out of memory|oom|cuda error|cudaError" | \
        awk '{print $1,$2,$3}' | sort | uniq -c | sort -rn | head -10 || echo "  無"

    echo ""
    echo "─ 崩潰 / 重啟 ─"
    journalctl -u llama-server --since "7 days ago" --no-pager 2>/dev/null | \
        grep -iE "killed|segfault|abort|core dumped|restarted" | \
        awk '{print $1,$2,$3}' | sort | uniq -c | sort -rn | head -10 || echo "  無"

    echo ""
    echo "─ 請求錯誤 ─"
    journalctl -u llama-server --since "7 days ago" --no-pager 2>/dev/null | \
        grep -iE "400|404|500|error.*request|timeout" | \
        awk '{print $1,$2,$3}' | sort | uniq -c | sort -rn | head -10 || echo "  無"

    echo ""
    echo "─ 高頻警告 ─"
    journalctl -u llama-server --since "7 days ago" --no-pager 2>/dev/null | \
        grep -i "warn" | awk '{for(i=5;i<=NF;i++) printf $i" "; print ""}' | \
        sort | uniq -c | sort -rn | head -10 || echo "  無"
    ;;

# ── 集中日誌設定 ──────────────────────────────────────────────────────────────
4)
    echo ""
    echo "設定 llama-server 寫入獨立日誌檔..."
    sudo tee /etc/rsyslog.d/50-llama.conf > /dev/null <<'EOF'
# llama-server 日誌
:programname, isequal, "llama-server" /var/log/llama-server.log
& stop
EOF
    sudo systemctl restart rsyslog 2>/dev/null || true
    echo "  ✓ 日誌將寫入：/var/log/llama-server.log"

    # logrotate
    sudo tee /etc/logrotate.d/llama-server > /dev/null <<'EOF'
/var/log/llama-server.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        systemctl restart rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    echo "  ✓ logrotate 已設定（每日輪替，保留 30 天）"
    ;;

esac

echo ""
echo "=== 完成 ==="
