#!/bin/bash
# Build a Release Pomodoro.app and install it to /Applications.
# Run any time you want to apply changes:
#   bash ~/pomodoro/install.sh

set -euo pipefail

cd "$(dirname "$0")"

DEST="/Applications/Pomodoro.app"
BUILD_DIR=".build"
PRODUCT="$BUILD_DIR/Build/Products/Release/Pomodoro.app"

echo "==> Regenerating Xcode project"
xcodegen generate >/dev/null

echo "==> Quitting running Pomodoro (if any)"
osascript -e 'tell application "Pomodoro" to quit' 2>/dev/null || true
# Give it a moment to release file locks.
sleep 1

echo "==> Building Release"
xcodebuild \
    -project Pomodoro.xcodeproj \
    -scheme Pomodoro \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    clean build \
    | grep -E "(error|warning|BUILD)" \
    | grep -v "AppIntents.framework" \
    || true

if [ ! -d "$PRODUCT" ]; then
    echo "Build failed — $PRODUCT not found" >&2
    exit 1
fi

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$PRODUCT" "$DEST"

echo ""
echo "Installed. Launch with:"
echo "  open $DEST"
echo ""
echo "To start at login:"
echo "  System Settings → General → Login Items & Extensions → add Pomodoro"
