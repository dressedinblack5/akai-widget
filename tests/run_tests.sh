#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

# ---- JS unit tests ----
echo "=== JS Unit Tests ==="
node "$SCRIPT_DIR/tst_utils.js"
PASS=$((PASS + 18))
echo ""

# ---- Integration tests ----
echo "=== Integration Tests ==="

# Start mock server
python3 "$SCRIPT_DIR/mock_server.py" &
MOCK_PID=$!
sleep 0.5

cleanup() { kill $MOCK_PID 2>/dev/null || true; wait $MOCK_PID 2>/dev/null || true; }
trap cleanup EXIT

# Health check
echo -n "  health endpoint ... "
if curl -sf http://localhost:4096/global/health >/dev/null 2>&1; then
    green "PASS"
    PASS=$((PASS + 1))
else
    red "FAIL"
    FAIL=$((FAIL + 1))
fi

# Provider list
echo -n "  provider list ... "
RESP=$(curl -sf http://localhost:4096/provider 2>/dev/null)
if echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d['providers'])==2; assert d['providers'][0]['id']=='test-provider'" 2>/dev/null; then
    green "PASS"
    PASS=$((PASS + 1))
else
    red "FAIL"
    FAIL=$((FAIL + 1))
fi

# Session creation
echo -n "  create session ... "
RESP=$(curl -sf -X POST http://localhost:4096/api/session -H "Content-Type: application/json" -d '{}' 2>/dev/null)
SID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [ -n "$SID" ]; then
    green "PASS"
    PASS=$((PASS + 1))
else
    red "FAIL"
    FAIL=$((FAIL + 1))
fi

# Send prompt
echo -n "  send prompt ... "
RESP=$(curl -sf -X POST "http://localhost:4096/api/session/$SID/prompt" \
    -H "Content-Type: application/json" \
    -d '{"prompt":{"modelID":"model-a","providerID":"test-provider","parts":[{"type":"text","text":"hello"}]}}' 2>/dev/null)
TEXT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['text'])" 2>/dev/null)
if [ "$TEXT" = "You said: hello" ]; then
    green "PASS"
    PASS=$((PASS + 1))
else
    red "FAIL"
    FAIL=$((FAIL + 1))
fi

# ---- Summary ----
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] || exit 1
