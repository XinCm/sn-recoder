#!/usr/bin/env bash
# Renders the panel to PNG files for visual inspection (no menu bar clicking).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"
MODULE_CACHE="$ROOT/.build/modulecache"

mkdir -p "$MODULE_CACHE" "$ROOT/build/previews"

SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find "$ROOT/MemoBar" -name '*.swift' ! -name 'MemoBarApp.swift' | sort)
SOURCES+=("$ROOT/Tools/PreviewRender/PreviewRenderer.swift")

swiftc \
    -parse-as-library \
    -swift-version 5 \
    -target "$(uname -m)-apple-macos13.0" \
    -sdk "$SDK" \
    -module-cache-path "$MODULE_CACHE" \
    -o "$ROOT/.build/PreviewRenderer" \
    "${SOURCES[@]}"

cd "$ROOT"
./.build/PreviewRenderer
