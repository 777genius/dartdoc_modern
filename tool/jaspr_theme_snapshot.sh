#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-/tmp/pw-run}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/jaspr-theme-shots}"
WAIT_MS="${WAIT_MS:-1500}"

if [ "$#" -gt 0 ]; then
  PRESETS=("$@")
else
  PRESETS=(ocean graphite forest)
fi

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

if [ ! -d "$PLAYWRIGHT_DIR/node_modules/playwright" ]; then
  echo "Playwright was not found in $PLAYWRIGHT_DIR."
  echo "Set PLAYWRIGHT_DIR to a directory that contains node_modules/playwright."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

manifest_file="$OUTPUT_DIR/manifest.json"
report_file="$OUTPUT_DIR/index.html"
manifest_entries=()

cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

index=0
for theme in "${PRESETS[@]}"; do
  port="$(find_free_port $((4312 + index * 10)))"
  preview_dir="/tmp/dartdoc-jaspr-preview-$theme"
  log_file="$OUTPUT_DIR/$theme-serve.log"

  cleanup

  THEME="$theme" \
  OUTPUT_DIR="$preview_dir" \
  PORT="$port" \
  "$ROOT/tool/jaspr_theme_preview.sh" >"$log_file" 2>&1 &
  SERVER_PID=$!

  for _ in $(seq 1 90); do
    if curl -sf "http://127.0.0.1:$port/guide/getting-started/" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! curl -sf "http://127.0.0.1:$port/guide/getting-started/" >/dev/null 2>&1; then
    echo "Preview for theme '$theme' did not start. See $log_file"
    exit 1
  fi

  THEME_NAME="$theme" \
  PORT="$port" \
  SHOT_DIR="$OUTPUT_DIR" \
  WAIT_MS="$WAIT_MS" \
  PLAYWRIGHT_DIR="$PLAYWRIGHT_DIR" \
  node - <<'NODE'
const path = require('path');
const fs = require('fs');
const { chromium } = require(path.join(process.env.PLAYWRIGHT_DIR, 'node_modules/playwright'));

(async () => {
  const url = `http://127.0.0.1:${process.env.PORT}/guide/getting-started/`;
  const waitMs = Number(process.env.WAIT_MS || 1500);
  const viewports = [
    {
      id: 'desktop',
      viewport: { width: 1440, height: 1100 },
      options: {},
    },
    {
      id: 'mobile',
      viewport: { width: 430, height: 932 },
      options: {
        isMobile: true,
        hasTouch: true,
        deviceScaleFactor: 2,
      },
    },
  ];
  const manifest = [];
  const modes = ['light', 'dark'];

  async function waitForStableLayout(page) {
    await page.waitForFunction(() => !!document.body, { timeout: 30000 });
    await page.evaluate(async () => {
      if (document.fonts?.ready) {
        await document.fonts.ready;
      }
    });

    await page.evaluate(async () => {
      if (typeof window.docsRenderMermaid === 'function') {
        try {
          await window.docsRenderMermaid(true);
        } catch (_) {
          // Ignore runtime Mermaid failures here; the page itself renders a fallback.
        }
      }
    });

    let stableTicks = 0;
    let lastHeight = -1;

    for (let index = 0; index < 75; index += 1) {
      const metrics = await page.evaluate(() => {
        const rootHeight = document.documentElement?.scrollHeight ?? 0;
        const bodyHeight = document.body?.scrollHeight ?? 0;
        const pendingMermaid = document.querySelectorAll(
          '.mermaid-diagram[data-mermaid-state="pending"]',
        ).length;
        const loadingImages = Array.from(document.images).filter(
          (image) => !image.complete,
        ).length;

        return {
          height: Math.max(rootHeight, bodyHeight),
          pendingMermaid,
          loadingImages,
        };
      });

      const isSettled =
        metrics.pendingMermaid === 0 &&
        metrics.loadingImages === 0 &&
        metrics.height === lastHeight;

      stableTicks = isSettled ? stableTicks + 1 : 0;
      lastHeight = metrics.height;

      if (stableTicks >= 4) {
        return;
      }

      await page.waitForTimeout(200);
    }

    throw new Error('Layout did not stabilize before screenshot capture.');
  }

  async function captureShot(view, mode) {
    const browser = await chromium.launch({ headless: true });
    try {
      const context = await browser.newContext({
        viewport: view.viewport,
        colorScheme: mode,
        ...view.options,
      });
      await context.addInitScript((theme) => {
        try {
          window.localStorage.setItem('jaspr:theme', theme);
        } catch (_) {
          // Ignore localStorage failures in locked-down browser contexts.
        }
        document.documentElement.setAttribute('data-theme', theme);
      }, mode);

      const page = await context.newPage();
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForFunction(
        (expectedTheme) =>
          document.documentElement.getAttribute('data-theme') === expectedTheme,
        mode,
        { timeout: 30000 },
      );
      await page.waitForTimeout(waitMs);
      await waitForStableLayout(page);

      const shotPath = path.join(
        process.env.SHOT_DIR,
        `${process.env.THEME_NAME}-${view.id}-${mode}.png`,
      );
      await page.screenshot({
        path: shotPath,
        fullPage: true,
      });

      await context.close();

      return {
        file: path.basename(shotPath),
        theme: process.env.THEME_NAME,
        viewport: view.id,
        mode,
      };
    } finally {
      await browser.close();
    }
  }

  for (const view of viewports) {
    for (const mode of modes) {
      manifest.push(await captureShot(view, mode));
    }
  }

  fs.writeFileSync(
    path.join(process.env.SHOT_DIR, `${process.env.THEME_NAME}.manifest.json`),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE

  cleanup
  manifest_entries+=("$theme")
  index=$((index + 1))
done

MANIFEST_FILE="$manifest_file" \
REPORT_FILE="$report_file" \
SHOT_DIR="$OUTPUT_DIR" \
THEMES="$(IFS=,; printf '%s' "${manifest_entries[*]}")" \
node - <<'NODE'
const fs = require('fs');
const path = require('path');
const manifestPath = process.env.MANIFEST_FILE;
const reportPath = process.env.REPORT_FILE;
const shotDir = process.env.SHOT_DIR;
const themes = (process.env.THEMES || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const entries = themes.flatMap((theme) => {
  const file = path.join(shotDir, `${theme}.manifest.json`);
  if (!fs.existsSync(file)) return [];
  return JSON.parse(fs.readFileSync(file, 'utf8'));
});

fs.writeFileSync(manifestPath, `${JSON.stringify(entries, null, 2)}\n`);

const grouped = new Map();

for (const entry of entries) {
  const key = entry.theme;
  if (!grouped.has(key)) grouped.set(key, []);
  grouped.get(key).push(entry);
}

const cards = [...grouped.entries()]
  .map(([theme, items]) => {
    items.sort((a, b) => {
      const aKey = `${a.viewport}-${a.mode}`;
      const bKey = `${b.viewport}-${b.mode}`;
      return aKey.localeCompare(bKey);
    });
    const figures = items
      .map((item) => {
        const label = `${item.viewport} / ${item.mode}`;
        return `
          <figure class="shot">
            <img src="./${item.file}" alt="${theme} ${label}">
            <figcaption>${label}</figcaption>
          </figure>
        `;
      })
      .join('\n');

    return `
      <section class="theme-card">
        <header>
          <h2>${theme}</h2>
          <p>${items.length} snapshots</p>
        </header>
        <div class="shot-grid">
          ${figures}
        </div>
      </section>
    `;
  })
  .join('\n');

const html = `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Jaspr Theme Snapshot Report</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #09090b;
        --surface: rgba(24, 24, 27, 0.96);
        --surface-soft: rgba(39, 39, 42, 0.96);
        --border: rgba(161, 161, 170, 0.24);
        --text: #fafafa;
        --muted: rgba(244, 244, 245, 0.64);
        --accent: #7dd3fc;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background:
          radial-gradient(circle at top left, rgba(125, 211, 252, 0.12), transparent 28rem),
          radial-gradient(circle at top right, rgba(34, 197, 94, 0.09), transparent 26rem),
          var(--bg);
        color: var(--text);
      }

      main {
        width: min(96rem, calc(100vw - 3rem));
        margin: 0 auto;
        padding: 2.5rem 0 4rem;
      }

      .page-header {
        margin-bottom: 2rem;
      }

      .page-header h1 {
        margin: 0 0 0.35rem;
        font-size: clamp(2rem, 4vw, 3.4rem);
        line-height: 1.05;
      }

      .page-header p {
        margin: 0;
        color: var(--muted);
        font-size: 1rem;
      }

      .theme-list {
        display: grid;
        gap: 1.5rem;
      }

      .theme-card {
        border: 1px solid var(--border);
        border-radius: 1.5rem;
        background: var(--surface);
        box-shadow: 0 30px 70px -38px rgba(0, 0, 0, 0.6);
        overflow: hidden;
      }

      .theme-card header {
        display: flex;
        justify-content: space-between;
        align-items: baseline;
        gap: 1rem;
        padding: 1.2rem 1.35rem;
        border-bottom: 1px solid var(--border);
        background: var(--surface-soft);
      }

      .theme-card h2 {
        margin: 0;
        font-size: 1.25rem;
        text-transform: capitalize;
      }

      .theme-card p {
        margin: 0;
        color: var(--muted);
        font-size: 0.92rem;
      }

      .shot-grid {
        display: grid;
        gap: 1rem;
        grid-template-columns: repeat(auto-fit, minmax(19rem, 1fr));
        padding: 1.2rem;
      }

      .shot {
        margin: 0;
        border: 1px solid var(--border);
        border-radius: 1rem;
        overflow: hidden;
        background: #0a0a0f;
      }

      .shot img {
        display: block;
        width: 100%;
        height: auto;
        background: white;
      }

      .shot figcaption {
        padding: 0.8rem 0.9rem;
        font-size: 0.88rem;
        color: var(--muted);
        border-top: 1px solid var(--border);
      }
    </style>
  </head>
  <body>
    <main>
      <header class="page-header">
        <h1>Jaspr Theme Snapshot Report</h1>
        <p>Desktop and mobile captures for each preset in light and dark mode.</p>
      </header>
      <div class="theme-list">
        ${cards}
      </div>
    </main>
  </body>
</html>
`;

fs.writeFileSync(reportPath, html);
NODE

echo "Saved screenshots to $OUTPUT_DIR"
echo "Manifest: $manifest_file"
echo "Report: $report_file"
