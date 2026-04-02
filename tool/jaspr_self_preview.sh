#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/dartdoc-vitepress-jaspr-self-preview}"
PUB_CACHE_DIR="${PUB_CACHE_DIR:-/tmp/dartdoc-pub-cache}"
PORT="${PORT:-4313}"
THEME="${THEME:-ocean}"
REUSE_BUILD="${REUSE_BUILD:-0}"

DART_BIN="/Users/belief/dev/flutter/bin/cache/dart-sdk/bin/dart"
JASPR_BIN="/Users/belief/.pub-cache/bin/jaspr"

write_home_page() {
  cat >"$OUTPUT_DIR/content/index.md" <<'EOF'
---
title: "dartdoc-vitepress"
description: "Modern API docs for Dart"
outline: false
---

# dartdoc-vitepress

Drop-in replacement for `dart doc` that generates a modern docs site with VitePress or Jaspr.

[Guide](/guide) | [API Reference](/api) | [GitHub](https://github.com/777genius/dartdoc_vitepress)

## Highlights

- Fast local search for guides and API pages
- Guide pages next to analyzer-driven API docs
- VitePress and Jaspr backends from one generator
- DartPad embeds, Mermaid, breadcrumbs, and theming
- Workspace docs support for larger Dart repos

## Install

```bash
dart pub global activate dartdoc_vitepress
```

## Quick Start

```bash
# VitePress output
dartdoc_vitepress --format vitepress --output docs-site

# Jaspr output
dartdoc_vitepress --format jaspr --output docs-site
```

## Compare Backends

| Backend | Best fit |
|---|---|
| `vitepress` | strongest static-site ecosystem and lowest-risk polished path |
| `jaspr` | Dart-first docs app scaffold with typed generated navigation |
| `html` | compatibility with the original dartdoc output |

## Live Example

[Dart SDK API docs](https://777genius.github.io/dart-sdk-api/) generated with `dartdoc-vitepress`.
EOF
}

port_is_busy() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

find_free_port() {
  local port="$1"
  while port_is_busy "$port"; do
    port=$((port + 1))
  done
  printf '%s\n' "$port"
}

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
PORT="$(find_free_port "$PORT")"

if [ "$REUSE_BUILD" != "1" ]; then
  rm -rf "$OUTPUT_DIR"

  EXCLUDES="$(
    {
      printf 'api_symbols\n'
      find "$ROOT/lib/resources/jaspr/lib" -name '*.dart' | sort | sed "s#^$ROOT/lib/#package:dartdoc_vitepress/#"
    } | paste -sd, -
  )"

  (
    cd "$ROOT"
    "$DART_BIN" run "$ROOT/bin/dartdoc_vitepress.dart" \
      --format jaspr \
      --guide-dirs docs-site/guide \
      --guide-exclude 'api/static-assets/.*' \
      --exclude "$EXCLUDES" \
      --output "$OUTPUT_DIR"
  )

  write_home_page

  (
    cd "$OUTPUT_DIR"
    PUB_CACHE="$PUB_CACHE_DIR" "$DART_BIN" pub get --offline
    PUB_CACHE="$PUB_CACHE_DIR" "$JASPR_BIN" build --dart-define "DOCS_THEME=$THEME"
  )
fi

STATIC_DIR="$OUTPUT_DIR/build/jaspr"
if [ ! -d "$STATIC_DIR" ]; then
  echo "Static Jaspr build output was not found at $STATIC_DIR."
  exit 1
fi

echo "Starting dartdoc-vitepress Jaspr self-preview on http://localhost:$PORT ..."
exec python3 -m http.server "$PORT" --directory "$STATIC_DIR"
