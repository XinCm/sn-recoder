#!/usr/bin/env bash
# Builds MemoBar.app with the command line toolchain (no Xcode project needed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MemoBar"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
SDK="$(xcrun --show-sdk-path)"
TARGET="$(uname -m)-apple-macos13.0"
MODULE_CACHE="$ROOT/.build/modulecache"

mkdir -p "$MODULE_CACHE" "$BUILD_DIR"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile every source in a deterministic order.
SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find "$ROOT/MemoBar" -name '*.swift' | sort)

echo "Compiling ${#SOURCES[@]} Swift files for ${TARGET}"
swiftc \
    -parse-as-library \
    -O \
    -swift-version 5 \
    -target "$TARGET" \
    -sdk "$SDK" \
    -module-cache-path "$MODULE_CACHE" \
    -o "$APP/Contents/MacOS/$APP_NAME" \
    "${SOURCES[@]}"

cp "$ROOT/MemoBar/Resources/Info.plist" "$APP/Contents/Info.plist"

if [[ -f "$ROOT/MemoBar/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/MemoBar/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
fi

# Ad-hoc signature: enough for local launch and for launch-at-login via LaunchAgent.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

SIZE="$(du -sh "$APP" | awk '{print $1}')"
echo "Built $APP ($SIZE)"
echo "Run with: open \"$APP\""
