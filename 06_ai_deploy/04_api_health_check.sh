#!/bin/bash
# 04_api_health_check.sh — AI API 服務健康檢查
set -e

echo "=== AI API 健康檢查 ==="
echo ""

# ── 1. 設定端點 ───────────────────────────────────────────────────────────────
read -rp "API Base URL [http://localhost:8080]: " API_BASE
API_BASE="${API_BASE:-http://localhost:8080}"

echo ""
echo "測試端點：$API_BASE"
echo ""

# ── 2. 基本健康檢查 ───────────────────────────────────────────────────────────
echo "[1/4] 基本健康檢查："

# /health
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_BASE}/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    HEALTH_BODY=$(curl -s "${API_BASE}/health" 2>/dev/null)
    echo "  ✓ /health → $HTTP_CODE | $HEALTH_BODY"
else
    echo "  ✗ /health → $HTTP_CODE（無法連線）"
fi

# /v1/models
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_BASE}/v1/models" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    MODEL_NAME=$(curl -s "${API_BASE}/v1/models" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null || echo "unknown")
    echo "  ✓ /v1/models → 模型：$MODEL_NAME"
else
    echo "  ✗ /v1/models → $HTTP_CODE"
fi
echo ""

# ── 3. 推理效能測試 ───────────────────────────────────────────────────────────
echo "[2/4] 推理效能測試（單次請求）："
START_TIME=$(date +%s%N)

RESPONSE=$(curl -s -X POST "${API_BASE}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "local",
        "messages": [{"role": "user", "content": "Say hello in one word"}],
        "max_tokens": 10,
        "temperature": 0
    }' 2>/dev/null || echo '{}')

END_TIME=$(date +%s%N)
ELAPSED=$(( (END_TIME - START_TIME) / 1000000 ))

if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null; then
    TOKENS=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")
    TPS=$(python3 -c "print(round(${TOKENS}*1000/${ELAPSED},1))" 2>/dev/null || echo "?")
    echo "  回應時間：${ELAPSED}ms | Tokens：$TOKENS | 速度：${TPS} tok/s"
else
    echo "  ✗ 推理失敗，回應：$(echo "$RESPONSE" | head -c 200)"
fi
echo ""

# ── 4. GPU 狀態（若有）───────────────────────────────────────────────────────
echo "[3/4] GPU 狀態："
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu \
        --format=csv,noheader | awk -F',' '{
        printf "  %s | VRAM: %s/%s | GPU: %s | 溫度: %s\n", $1,$2,$3,$4,$5}'
else
    echo "  GPU 不可用"
fi
echo ""

# ── 5. 服務程序 ───────────────────────────────────────────────────────────────
echo "[4/4] AI 相關 Process："
ps aux | grep -E "llama|uvicorn|python.*serve|ollama" | grep -v grep | \
    awk '{printf "  PID %-8s CPU %5s%% MEM %5s%%  %s\n", $2, $3, $4, $11}' || \
    echo "  未找到 AI 相關 Process"

echo ""
echo "=== 健康檢查完成 ==="
echo "API 狀態：$API_BASE"
echo "持續監控：watch -n 5 'bash $0'"
