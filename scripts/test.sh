#!/usr/bin/env bash
# Compiles and runs the model/persistence tests (no UI required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"
MODULE_CACHE="$ROOT/.build/modulecache"
mkdir -p "$MODULE_CACHE"

SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(
    find "$ROOT/MemoBar/Models" "$ROOT/MemoBar/Services" "$ROOT/MemoBar/Stores" -name '*.swift' | sort
)
SOURCES+=("$ROOT/Tests/MemoBarTests.swift")

swiftc \
    -parse-as-library \
    -swift-version 5 \
    -target "$(uname -m)-apple-macos13.0" \
    -sdk "$SDK" \
    -module-cache-path "$MODULE_CACHE" \
    -o "$ROOT/.build/MemoBarTests" \
    "${SOURCES[@]}"

cd "$ROOT"
./.build/MemoBarTests
