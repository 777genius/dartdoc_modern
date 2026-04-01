#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
TEST_PACKAGE_DIR="${TEST_PACKAGE_DIR:-$ROOT/testing/test_package_with_docs}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/dartdoc-jaspr-preview}"
PUB_CACHE_DIR="${PUB_CACHE_DIR:-/tmp/dartdoc-pub-cache}"
PROXY_PORT="${PORT:-4312}"
REQUESTED_SERVER_PORT="${SERVER_PORT:-8080}"
SERVER_PORT=8080
THEME="${THEME:-ocean}"
BASE_PATH="${BASE_PATH:-}"
REUSE_BUILD="${REUSE_BUILD:-0}"

DART_BIN="/Users/belief/dev/flutter/bin/cache/dart-sdk/bin/dart"
DART_DIR="/Users/belief/dev/flutter/bin/cache/dart-sdk/bin"
JASPR_BIN="/Users/belief/.pub-cache/bin/jaspr"

normalize_base_path() {
  local value="$1"
  if [ -z "$value" ] || [ "$value" = "/" ]; then
    printf '\n'
    return 0
  fi

  value="/${value#/}"
  value="${value%/}"
  printf '%s\n' "$value"
}

port_is_busy() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

listener_pids() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -Fp 2>/dev/null |
    sed -n 's/^p//p' |
    sort -u
}

process_cwd() {
  local pid="$1"
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null |
    sed -n 's/^n//p' |
    head -n 1
}

process_command() {
  local pid="$1"
  ps -p "$pid" -o command= 2>/dev/null | sed 's/^ *//'
}

is_our_preview_process() {
  local pid="$1"
  local cwd
  cwd="$(process_cwd "$pid")"

  case "$cwd" in
    /tmp/dartdoc-jaspr-preview* | /private/tmp/dartdoc-jaspr-preview*)
      return 0
      ;;
  esac

  local command
  command="$(process_command "$pid")"
  [[ "$command" == *".dart_tool/jaspr/server_target.dart"* &&
    "$command" == *"dartdoc-jaspr-preview"* ]]
}

kill_stale_preview_port() {
  local port="$1"
  local killed=0

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if is_our_preview_process "$pid"; then
      echo "Stopping stale Jaspr preview on port $port (pid $pid)..."
      kill "$pid" 2>/dev/null || true
      killed=1
    fi
  done < <(listener_pids "$port")

  if [ "$killed" -eq 1 ]; then
    for _ in $(seq 1 20); do
      if ! port_is_busy "$port"; then
        return 0
      fi
      sleep 1
    done
  fi
}

fail_for_blocked_port() {
  local port="$1"
  local label="$2"
  local pid
  pid="$(listener_pids "$port" | head -n 1)"
  local command cwd
  command="$(process_command "$pid")"
  cwd="$(process_cwd "$pid")"

  echo "Cannot start Jaspr preview: $label port $port is already in use."
  echo "Listener PID: $pid"
  if [ -n "$command" ]; then
    echo "Command: $command"
  fi
  if [ -n "$cwd" ]; then
    echo "Working directory: $cwd"
  fi
  echo "The current Jaspr preview flow still expects the internal app server on port 8080."
  echo "Close the other listener or rerun after stopping the stale process."
  exit 1
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
BASE_PATH="$(normalize_base_path "$BASE_PATH")"

if [ -n "${SERVER_PORT_OVERRIDE:-}" ] && [ "$SERVER_PORT_OVERRIDE" != "8080" ]; then
  echo "Ignoring SERVER_PORT_OVERRIDE=$SERVER_PORT_OVERRIDE. Jaspr preview still uses internal port 8080."
fi

if [ -n "$REQUESTED_SERVER_PORT" ] && [ "$REQUESTED_SERVER_PORT" != "8080" ]; then
  echo "Ignoring SERVER_PORT=$REQUESTED_SERVER_PORT. Jaspr build still uses internal port 8080."
fi

if [ -n "${WEB_PORT:-}" ] && [ "${WEB_PORT}" != "5470" ]; then
  echo "Ignoring WEB_PORT=${WEB_PORT}. Static preview no longer uses a separate web compiler port."
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for static Jaspr preview serving."
  exit 1
fi

kill_stale_preview_port "$SERVER_PORT"
kill_stale_preview_port "$PROXY_PORT"

if port_is_busy "$SERVER_PORT"; then
  fail_for_blocked_port "$SERVER_PORT" "internal server"
fi

PROXY_PORT="$(find_free_port "$PROXY_PORT")"

if [ "$REUSE_BUILD" = "1" ]; then
  echo "Reusing existing Jaspr preview in $OUTPUT_DIR with theme '$THEME'..."
else
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

  echo "Building static Jaspr preview..."

  (
    cd "$OUTPUT_DIR"
    export PATH="$DART_DIR:$PATH"
    PUB_CACHE="$PUB_CACHE_DIR" "$JASPR_BIN" build \
      --dart-define "DOCS_THEME=$THEME" \
      --dart-define "DOCS_BASE_PATH=$BASE_PATH"
  )
fi

STATIC_DIR="$OUTPUT_DIR/build/jaspr"

if [ ! -d "$STATIC_DIR" ]; then
  echo "Static Jaspr build output was not found at $STATIC_DIR."
  exit 1
fi

SERVE_DIR="$STATIC_DIR"
PREVIEW_PATH="/guide/getting-started/"

if [ -n "$BASE_PATH" ]; then
  SERVE_DIR="$OUTPUT_DIR/.serve-root"
  TARGET_DIR="$SERVE_DIR$BASE_PATH"

  rm -rf "$SERVE_DIR"
  mkdir -p "$TARGET_DIR"
  cp -R "$STATIC_DIR"/. "$TARGET_DIR"/

  PREVIEW_PATH="$BASE_PATH/guide/getting-started/"
fi

echo "Starting Jaspr preview on http://localhost:$PROXY_PORT ..."
echo "Theme preset: $THEME"
if [ -n "$BASE_PATH" ]; then
  echo "Base path: $BASE_PATH"
fi
echo "Preview entry: http://localhost:$PROXY_PORT$PREVIEW_PATH"

exec python3 -m http.server "$PROXY_PORT" --directory "$SERVE_DIR"
