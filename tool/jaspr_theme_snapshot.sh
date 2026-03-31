#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-/tmp/pw-run}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/jaspr-theme-shots}"
PRESETS=("${@:-ocean graphite forest}")

if [ ! -d "$PLAYWRIGHT_DIR/node_modules/playwright" ]; then
  echo "Playwright was not found in $PLAYWRIGHT_DIR."
  echo "Set PLAYWRIGHT_DIR to a directory that contains node_modules/playwright."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

index=0
for theme in "${PRESETS[@]}"; do
  port=$((4312 + index * 10))
  web_port=$((5470 + index * 10))
  preview_dir="/tmp/dartdoc-jaspr-preview-$theme"
  log_file="$OUTPUT_DIR/$theme-serve.log"

  cleanup

  THEME="$theme" \
  PORT="$port" \
  WEB_PORT="$web_port" \
  OUTPUT_DIR="$preview_dir" \
  "$ROOT/tool/jaspr_theme_preview.sh" >"$log_file" 2>&1 &
  SERVER_PID=$!

  for _ in $(seq 1 90); do
    if curl -sf "http://127.0.0.1:$port/guide/getting-started" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! curl -sf "http://127.0.0.1:$port/guide/getting-started" >/dev/null 2>&1; then
    echo "Preview for theme '$theme' did not start. See $log_file"
    exit 1
  fi

  THEME_NAME="$theme" \
  PORT="$port" \
  SHOT_DIR="$OUTPUT_DIR" \
  PLAYWRIGHT_DIR="$PLAYWRIGHT_DIR" \
  node - <<'NODE'
const path = require('path');
const { chromium } = require(path.join(process.env.PLAYWRIGHT_DIR, 'node_modules/playwright'));

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
  const url = `http://127.0.0.1:${process.env.PORT}/guide/getting-started`;
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(1500);
  await page.screenshot({
    path: path.join(process.env.SHOT_DIR, `${process.env.THEME_NAME}-light.png`),
    fullPage: true,
  });
  const toggle = page.locator('.theme-toggle');
  if (await toggle.count()) {
    await toggle.click();
    await page.waitForTimeout(400);
  }
  await page.screenshot({
    path: path.join(process.env.SHOT_DIR, `${process.env.THEME_NAME}-dark.png`),
    fullPage: true,
  });
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE

  cleanup
  index=$((index + 1))
done

echo "Saved screenshots to $OUTPUT_DIR"
