#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
TEST_PACKAGE_DIR="${TEST_PACKAGE_DIR:-$ROOT/testing/test_package_with_docs}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/dartdoc-jaspr-preview}"
PUB_CACHE_DIR="${PUB_CACHE_DIR:-/tmp/dartdoc-pub-cache}"
PORT="${PORT:-4312}"
WEB_PORT="${WEB_PORT:-5470}"
THEME="${THEME:-ocean}"

DART_BIN="/Users/belief/dev/flutter/bin/cache/dart-sdk/bin/dart"
DART_DIR="/Users/belief/dev/flutter/bin/cache/dart-sdk/bin"
JASPR_BIN="/Users/belief/.pub-cache/bin/jaspr"

prepare_pub_cache() {
  mkdir -p "$PUB_CACHE_DIR"

  if [ ! -e "$PUB_CACHE_DIR/hosted" ]; then
    ln -s /Users/belief/.pub-cache/hosted "$PUB_CACHE_DIR/hosted"
  fi

  if [ -d /Users/belief/.pub-cache/git ] && [ ! -e "$PUB_CACHE_DIR/git" ]; then
    ln -s /Users/belief/.pub-cache/git "$PUB_CACHE_DIR/git"
  fi

  if [ -d /Users/belief/.pub-cache/hosted-hashes ] && [ ! -e "$PUB_CACHE_DIR/hosted-hashes" ]; then
    ln -s /Users/belief/.pub-cache/hosted-hashes "$PUB_CACHE_DIR/hosted-hashes"
  fi
}

prepare_pub_cache

echo "Generating Jaspr docs into $OUTPUT_DIR using theme '$THEME'..."
mkdir -p "$OUTPUT_DIR"

(
  cd "$TEST_PACKAGE_DIR"
  "$DART_BIN" run "$ROOT/bin/dartdoc_vitepress.dart" --format jaspr --output "$OUTPUT_DIR"
)

echo "Resolving dependencies offline..."
(
  cd "$OUTPUT_DIR"
  PUB_CACHE="$PUB_CACHE_DIR" "$DART_BIN" pub get --offline
)

echo "Starting Jaspr preview on http://localhost:$PORT ..."
echo "Theme preset: $THEME"

(
  cd "$OUTPUT_DIR"
  export PATH="$DART_DIR:$PATH"
  PUB_CACHE="$PUB_CACHE_DIR" "$JASPR_BIN" serve \
    --proxy-port "$PORT" \
    --web-port "$WEB_PORT" \
    --dart-define "DOCS_THEME=$THEME"
)
