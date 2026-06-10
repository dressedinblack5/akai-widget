#!/usr/bin/env bash
set -euo pipefail

PLASMOID_NAME="akai-chat"
SRC_DIR="$(dirname "$0")/package"
DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$PLASMOID_NAME"

echo "Installing $PLASMOID_NAME..."
rm -rf "$DEST_DIR"
cp -r "$SRC_DIR" "$DEST_DIR"
echo "Installed to $DEST_DIR"
echo ""
echo "To add the widget: right-click panel → Add Widgets → AKAI Chat"
echo "Or test with: plasmoidviewer -a $PLASMOID_NAME"
echo ""
echo "To run tests: ./tests/run_tests.sh"
