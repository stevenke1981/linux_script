#!/bin/bash
# 02_gpu_health_check.sh — GPU 健康檢查與 OOM 預防
set -e

echo "=== GPU 健康檢查 ==="
echo ""

# ── 確認 nvidia-smi ───────────────────────────────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
    echo "✗ nvidia-smi 不可用，請先安裝 NVIDIA 驅動"
    exit 1
fi

# ── 1. GPU 基本資訊 ───────────────────────────────────────────────────────────
echo "[1/5] GPU 基本資訊："
nvidia-smi --query-gpu=index,name,driver_version,memory.total,compute_cap \
    --format=csv,noheader | awk -F',' '{
    printf "  GPU %s: %s\n", $1, $2
    printf "    驅動版本：%s\n", $3
    printf "    顯存總量：%s\n", $4
    printf "    Compute：%s\n", $5
}'
echo ""

# ── 2. 目前 VRAM 使用狀況 ─────────────────────────────────────────────────────
echo "[2/5] VRAM 使用狀況："
nvidia-smi --query-gpu=index,memory.used,memory.free,memory.total,utilization.gpu,temperature.gpu \
    --format=csv,noheader | awk -F',' '{
    used=$2+0; free=$3+0; total=$4+0
    pct = (total>0) ? int(used*100/total) : 0
    printf "  GPU %s: 已用 %s / %s (%d%%)  GPU使用率:%s  溫度:%s\n",
           $1, $2, $4, pct, $5, $6
}'
echo ""

# ── 3. 佔用 VRAM 的 Process ───────────────────────────────────────────────────
echo "[3/5] 使用 GPU 的 Process："
GPU_PROCS=$(nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null)
if [ -n "$GPU_PROCS" ]; then
    echo "$GPU_PROCS" | awk -F',' '{printf "  PID %-8s VRAM %-10s %s\n", $1, $2, $3}'
else
    echo "  目前無 Process 使用 GPU"
fi
echo ""

# ── 4. 溫度與功耗 ─────────────────────────────────────────────────────────────
echo "[4/5] 溫度與功耗："
nvidia-smi --query-gpu=index,temperature.gpu,power.draw,power.limit,fan.speed \
    --format=csv,noheader | awk -F',' '{
    temp=$2+0
    status = (temp>=85) ? "⚠ 過熱！" : (temp>=75) ? "! 注意" : "✓ 正常"
    printf "  GPU %s: 溫度 %s°C %s | 功耗 %s / %s | 風扇 %s\n",
           $1, $2, status, $3, $4, $5
}'
echo ""

# ── 5. OOM 預防建議 ───────────────────────────────────────────────────────────
echo "[5/5] OOM 預防設定："
# 計算推薦模型大小
TOTAL_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1 | tr -dc '0-9')
USED_VRAM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader | head -1 | tr -dc '0-9')
FREE_VRAM=$(( TOTAL_VRAM - USED_VRAM ))

echo "  可用 VRAM：${FREE_VRAM} MiB / ${TOTAL_VRAM} MiB"
echo ""
echo "  推薦模型大小（GGUF Q4_K_M）："
echo "    7B  模型需要約 4-5 GB VRAM"
echo "    13B 模型需要約 8-9 GB VRAM"
echo "    34B 模型需要約 20 GB VRAM"
echo "    70B 模型需要約 40 GB VRAM"
echo ""

if [ "$FREE_VRAM" -gt 0 ]; then
    RECOMMENDED_B=$(( FREE_VRAM / 700 ))
    echo "  依目前可用 VRAM（${FREE_VRAM}MiB），建議使用 ${RECOMMENDED_B}B 以下模型"
fi

echo ""
echo "=== 診斷完成 ==="
echo "持續監控：watch -n 2 nvidia-smi"
