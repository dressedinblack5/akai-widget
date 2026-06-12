#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== akai-widget tests ==="
echo ""

echo "--- Unit tests (utils.js) ---"
node "$SCRIPT_DIR/tst_utils.js"
echo ""

echo "=== All tests passed ==="
