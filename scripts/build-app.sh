#!/usr/bin/env bash
# Builds "Dodo for Mac.app" into ./build (universal binary: Apple Silicon + Intel).
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="Dodo for Mac"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

ARCH_FLAGS=(--arch arm64 --arch x86_64)
if [[ "${SINGLE_ARCH:-0}" == "1" ]]; then
  ARCH_FLAGS=()
fi

echo "==> Compiling"
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/DodoMac" "$APP/Contents/MacOS/DodoMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" || true
fi

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
echo "    Open it with: open \"$APP\""
