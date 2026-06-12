#!/usr/bin/env bash
set -euo pipefail

PLASMOID_NAME="akai-widget"
SRC_DIR="$(dirname "$0")/package"
DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$PLASMOID_NAME"

echo "Installing $PLASMOID_NAME..."

if [ ! -d "build" ]; then
    echo "Configuring build..."
    cmake -B build -DCMAKE_INSTALL_PREFIX=~/.local
fi

echo "Building plugin..."
cmake --build build

rm -rf "$DEST_DIR"
cp -r "$SRC_DIR" "$DEST_DIR"

if [ -f "build/package/contents/ui/code/libakaiwidgetplugin.so" ]; then
    mkdir -p "$DEST_DIR/contents/ui/code"
    cp build/package/contents/ui/code/libakaiwidgetplugin.so "$DEST_DIR/contents/ui/code/"
    cp build/package/contents/ui/code/libakaiwidgetpluginplugin.so "$DEST_DIR/contents/ui/code/"
    cp build/package/contents/ui/code/qmldir "$DEST_DIR/contents/ui/code/"
    cp build/package/contents/ui/code/akaiwidgetplugin.qmltypes "$DEST_DIR/contents/ui/code/" 2>/dev/null || true
fi

echo "Installed to $DEST_DIR"
echo ""
echo "Add widget: right-click panel → Add Widgets → AKAI Widget"
echo "Test: plasmoidviewer -a $PLASMOID_NAME"
