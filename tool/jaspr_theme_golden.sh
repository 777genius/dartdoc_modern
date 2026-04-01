#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
MODE="${1:-verify}"
PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-/tmp/pw-run}"
BASELINE_DIR="${BASELINE_DIR:-$ROOT/test/goldens/jaspr_theme}"
WORK_DIR="${WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dartdoc-jaspr-golden.XXXXXX")}"
SNAPSHOT_DIR="$WORK_DIR/shots"
DIFF_DIR="$WORK_DIR/diffs"
REPORT_BASELINE_DIR="$WORK_DIR/baseline"
REPORT_FILE="$WORK_DIR/index.html"
THRESHOLD="${RMSE_THRESHOLD:-0.0025}"
KEEP_WORK_DIR="${KEEP_WORK_DIR:-0}"

cleanup() {
  if [ "$KEEP_WORK_DIR" != "1" ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
}

trap cleanup EXIT

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required. Install 'magick' before running Jaspr golden checks."
  exit 1
fi

if [ ! -d "$PLAYWRIGHT_DIR/node_modules/playwright" ]; then
  echo "Playwright was not found in $PLAYWRIGHT_DIR."
  echo "Set PLAYWRIGHT_DIR to a directory that contains node_modules/playwright."
  exit 1
fi

mkdir -p "$SNAPSHOT_DIR" "$DIFF_DIR" "$REPORT_BASELINE_DIR"

run_snapshot_matrix() {
  PLAYWRIGHT_DIR="$PLAYWRIGHT_DIR" OUTPUT_DIR="$SNAPSHOT_DIR" \
    "$ROOT/tool/jaspr_theme_snapshot.sh"
}

copy_baseline() {
  rm -rf "$BASELINE_DIR"
  mkdir -p "$BASELINE_DIR"

  cp "$SNAPSHOT_DIR"/manifest.json "$BASELINE_DIR/manifest.json"
  for file in "$SNAPSHOT_DIR"/*.png; do
    cp "$file" "$BASELINE_DIR/$(basename "$file")"
  done
}

build_report() {
  local entries_json="$1"
  ENTRIES_JSON="$entries_json" REPORT_FILE="$REPORT_FILE" node - <<'NODE'
const fs = require('fs');
const entries = JSON.parse(process.env.ENTRIES_JSON);
const reportPath = process.env.REPORT_FILE;

const cards = entries.map((entry) => {
  const statusClass = entry.passed ? 'passed' : 'failed';
  const diffImage = entry.diffFile
    ? `<figure><img src="./diffs/${entry.diffFile}" alt="diff ${entry.file}"><figcaption>Diff</figcaption></figure>`
    : '';
  return `
    <section class="card ${statusClass}">
      <header>
        <h2>${entry.file}</h2>
        <p>${entry.theme} / ${entry.viewport} / ${entry.mode}</p>
      </header>
      <div class="metric-row">
        <span>RMSE: <strong>${entry.metric}</strong></span>
        <span>Threshold: <strong>${entry.threshold}</strong></span>
        <span class="status">${entry.passed ? 'PASS' : 'FAIL'}</span>
      </div>
      <div class="grid">
        <figure>
          <img src="${entry.baselineRel}" alt="baseline ${entry.file}">
          <figcaption>Baseline</figcaption>
        </figure>
        <figure>
          <img src="./shots/${entry.file}" alt="current ${entry.file}">
          <figcaption>Current</figcaption>
        </figure>
        ${diffImage}
      </div>
    </section>
  `;
}).join('\n');

const failed = entries.filter((entry) => !entry.passed).length;
const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Jaspr Theme Golden Report</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #09090b;
        --surface: rgba(24, 24, 27, 0.96);
        --surface-soft: rgba(39, 39, 42, 0.96);
        --border: rgba(161, 161, 170, 0.24);
        --text: #fafafa;
        --muted: rgba(244, 244, 245, 0.64);
        --pass: #22c55e;
        --fail: #fb7185;
      }

      * { box-sizing: border-box; }

      body {
        margin: 0;
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background:
          radial-gradient(circle at top left, rgba(125, 211, 252, 0.1), transparent 28rem),
          radial-gradient(circle at top right, rgba(52, 211, 153, 0.08), transparent 25rem),
          var(--bg);
        color: var(--text);
      }

      main {
        width: min(110rem, calc(100vw - 3rem));
        margin: 0 auto;
        padding: 2.5rem 0 4rem;
      }

      .page-header {
        margin-bottom: 1.8rem;
      }

      .page-header h1 {
        margin: 0 0 0.35rem;
        font-size: clamp(2rem, 4vw, 3.2rem);
        line-height: 1.05;
      }

      .page-header p {
        margin: 0;
        color: var(--muted);
      }

      .summary {
        display: flex;
        gap: 1rem;
        flex-wrap: wrap;
        margin: 1.2rem 0 2rem;
      }

      .pill {
        border: 1px solid var(--border);
        background: var(--surface-soft);
        border-radius: 999px;
        padding: 0.55rem 0.9rem;
      }

      .cards {
        display: grid;
        gap: 1.2rem;
      }

      .card {
        border: 1px solid var(--border);
        border-radius: 1.35rem;
        background: var(--surface);
        overflow: hidden;
      }

      .card.failed {
        border-color: rgba(251, 113, 133, 0.55);
      }

      .card.passed {
        border-color: rgba(34, 197, 94, 0.35);
      }

      .card header {
        padding: 1rem 1.2rem 0.7rem;
        border-bottom: 1px solid var(--border);
      }

      .card header h2 {
        margin: 0 0 0.22rem;
        font-size: 1.08rem;
      }

      .card header p {
        margin: 0;
        color: var(--muted);
        font-size: 0.9rem;
      }

      .metric-row {
        display: flex;
        gap: 1rem;
        flex-wrap: wrap;
        padding: 0.85rem 1.2rem 0;
        color: var(--muted);
        font-size: 0.9rem;
      }

      .status {
        color: ${failed > 0 ? 'var(--fail)' : 'var(--pass)'};
        font-weight: 700;
      }

      .grid {
        display: grid;
        gap: 1rem;
        grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr));
        padding: 1rem 1.2rem 1.2rem;
      }

      figure {
        margin: 0;
        border: 1px solid var(--border);
        border-radius: 1rem;
        overflow: hidden;
        background: #0a0a0f;
      }

      img {
        display: block;
        width: 100%;
        height: auto;
      }

      figcaption {
        padding: 0.75rem 0.85rem;
        border-top: 1px solid var(--border);
        color: var(--muted);
        font-size: 0.86rem;
      }
    </style>
  </head>
  <body>
    <main>
      <header class="page-header">
        <h1>Jaspr Theme Golden Report</h1>
        <p>Production-like snapshot comparison for the generated Jaspr themes.</p>
      </header>
      <div class="summary">
        <div class="pill">Compared: <strong>${entries.length}</strong></div>
        <div class="pill">Failures: <strong>${failed}</strong></div>
      </div>
      <div class="cards">
        ${cards}
      </div>
    </main>
  </body>
</html>`;

fs.writeFileSync(reportPath, html);
NODE
}

verify_against_baseline() {
  if [ ! -f "$BASELINE_DIR/manifest.json" ]; then
    echo "Golden baseline was not found at $BASELINE_DIR/manifest.json"
    echo "Run: PLAYWRIGHT_DIR=$PLAYWRIGHT_DIR $ROOT/tool/jaspr_theme_golden.sh update"
    exit 1
  fi

  local baseline_entries
  baseline_entries="$(cat "$BASELINE_DIR/manifest.json")"
  local entries_json='[]'
  local failures=0

  while IFS=$'\t' read -r file theme viewport mode; do
    [ -n "$file" ] || continue
    local baseline_file="$BASELINE_DIR/$file"
    local current_file="$SNAPSHOT_DIR/$file"
    local diff_file="${file%.png}.diff.png"
    local diff_path="$DIFF_DIR/$diff_file"
    local report_baseline_file="$REPORT_BASELINE_DIR/$file"

    if [ ! -f "$baseline_file" ]; then
      echo "Missing baseline image: $baseline_file"
      failures=$((failures + 1))
      continue
    fi

    if [ ! -f "$current_file" ]; then
      echo "Missing current image: $current_file"
      failures=$((failures + 1))
      continue
    fi

    cp "$baseline_file" "$report_baseline_file"

    local metric_output
    set +e
    metric_output="$(magick compare -metric RMSE "$baseline_file" "$current_file" "$diff_path" 2>&1 >/dev/null)"
    local compare_status=$?
    set -e

    local normalized
    normalized="$(printf '%s\n' "$metric_output" | sed -n 's/.*(\([0-9.][0-9.]*\)).*/\1/p' | tail -n 1)"
    if [ -z "$normalized" ]; then
      normalized="1"
    fi

    local passed="true"
    if ! awk "BEGIN { exit !($normalized <= $THRESHOLD) }"; then
      passed="false"
      failures=$((failures + 1))
    elif [ -f "$diff_path" ]; then
      rm -f "$diff_path"
      diff_file=""
    fi

    if [ "$compare_status" -gt 1 ]; then
      passed="false"
      failures=$((failures + 1))
    fi

    local entry_json
    entry_json="$(FILE="$file" THEME="$theme" VIEWPORT="$viewport" MODE="$mode" \
      NORMALIZED="$normalized" THRESHOLD_VALUE="$THRESHOLD" PASSED="$passed" \
      DIFF_FILE="$diff_file" BASELINE_REL="./baseline/$file" node - <<'NODE'
const entry = {
  file: process.env.FILE,
  theme: process.env.THEME,
  viewport: process.env.VIEWPORT,
  mode: process.env.MODE,
  metric: Number(process.env.NORMALIZED || '1').toFixed(6),
  threshold: Number(process.env.THRESHOLD_VALUE || '0').toFixed(6),
  passed: process.env.PASSED === 'true',
  diffFile: process.env.DIFF_FILE || '',
  baselineRel: process.env.BASELINE_REL,
};
process.stdout.write(JSON.stringify(entry));
NODE
)"

    entries_json="$(
      EXISTING="$entries_json" ENTRY="$entry_json" node - <<'NODE'
const entries = JSON.parse(process.env.EXISTING);
entries.push(JSON.parse(process.env.ENTRY));
process.stdout.write(JSON.stringify(entries));
NODE
)"
  done < <(
    MANIFEST="$baseline_entries" node - <<'NODE'
const manifest = JSON.parse(process.env.MANIFEST);
for (const entry of manifest) {
  console.log([entry.file, entry.theme, entry.viewport, entry.mode].join('\t'));
}
NODE
  )

  build_report "$entries_json"

  if [ "$failures" -gt 0 ]; then
    echo "Jaspr theme golden verification failed."
    echo "Report: $REPORT_FILE"
    KEEP_WORK_DIR=1
    exit 1
  fi

  echo "Jaspr theme golden verification passed."
  echo "Report: $REPORT_FILE"
}

case "$MODE" in
  update)
    run_snapshot_matrix
    copy_baseline
    echo "Updated Jaspr theme goldens in $BASELINE_DIR"
    ;;
  verify)
    run_snapshot_matrix
    verify_against_baseline
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [update|verify]"
    exit 1
    ;;
esac
