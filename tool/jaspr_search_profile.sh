#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-/tmp/pw-run}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/jaspr-search-profile}"
PREVIEW_DIR="${PREVIEW_DIR:-$OUTPUT_DIR/preview}"
PORT="${PORT:-4341}"
THEME="${THEME:-ocean}"
REUSE_BUILD="${REUSE_BUILD:-0}"
REPORT_FILE="$OUTPUT_DIR/report.json"

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
PORT="$(find_free_port "$PORT")"
LOG_FILE="$OUTPUT_DIR/preview.log"

cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

THEME="$THEME" \
REUSE_BUILD="$REUSE_BUILD" \
OUTPUT_DIR="$PREVIEW_DIR" \
PORT="$PORT" \
"$ROOT/tool/jaspr_theme_preview.sh" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 120); do
  if curl -sf "http://127.0.0.1:$PORT/guide/getting-started/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -sf "http://127.0.0.1:$PORT/guide/getting-started/" >/dev/null 2>&1; then
  echo "Preview did not start. See $LOG_FILE"
  exit 1
fi

PLAYWRIGHT_DIR="$PLAYWRIGHT_DIR" \
PORT="$PORT" \
REPORT_FILE="$REPORT_FILE" \
node - <<'NODE'
const fs = require('fs');
const path = require('path');
const { chromium } = require(path.join(process.env.PLAYWRIGHT_DIR, 'node_modules/playwright'));

const url = `http://127.0.0.1:${process.env.PORT}/guide/getting-started/`;
const reportFile = process.env.REPORT_FILE;
const scenarios = [
  {
    id: 'desktop',
    viewport: { width: 1440, height: 1100 },
    cpuThrottlingRate: 1,
    options: {},
  },
  {
    id: 'mobile',
    viewport: { width: 430, height: 932 },
    cpuThrottlingRate: 4,
    options: {
      isMobile: true,
      hasTouch: true,
      deviceScaleFactor: 3,
    },
  },
];

function filterSearchRequests(names) {
  return names.filter((name) => name.includes('/generated/search_'));
}

async function collectSearchRequestNames(page) {
  return page.evaluate(() =>
    performance
      .getEntriesByType('resource')
      .map((entry) => entry.name)
      .filter((name) => name.includes('/generated/search_')),
  );
}

async function waitForSearchIdle(page) {
  await page.waitForFunction(() => {
    const status = document.querySelector('.docs-search-status')?.textContent ?? '';
    if (!status) return false;
    return !/Loading search|Searching/.test(status);
  }, { timeout: 30000 });
}

async function openSearch(page) {
  const start = Date.now();
  await page.click('[data-docs-search-launcher]');
  await page.waitForSelector('[data-docs-search-overlay]:not([hidden])', { timeout: 30000 });
  await waitForSearchIdle(page);
  return Date.now() - start;
}

async function runQuery(page, value) {
  const start = Date.now();
  await page.fill('[data-search-input]', value);
  await page.waitForFunction(() => {
    const status = document.querySelector('.docs-search-status')?.textContent?.trim() ?? '';
    if (/Loading search|Searching/.test(status)) return false;
    return /^\d+ result/.test(status) || status === 'No results found.';
  }, { timeout: 30000 });

  return page.evaluate(
    ({ start, value }) => {
      const results = Array.from(document.querySelectorAll('.docs-search-result'));
      const first = results[0];
      const firstTitle =
        first?.querySelector('.docs-search-title')?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
      const status =
        document.querySelector('.docs-search-status')?.textContent?.trim() ?? '';
      return {
        query: value,
        elapsedMs: Date.now() - start,
        resultCount: results.length,
        status,
        firstTitle,
      };
    },
    { start, value },
  );
}

async function profileScenario(browser, scenario) {
  const context = await browser.newContext({
    viewport: scenario.viewport,
    colorScheme: 'light',
    ...scenario.options,
  });
  const page = await context.newPage();
  const session = await context.newCDPSession(page);
  if (scenario.cpuThrottlingRate > 1) {
    await session.send('Emulation.setCPUThrottlingRate', {
      rate: scenario.cpuThrottlingRate,
    });
  }

  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

  const firstOpenMs = await openSearch(page);
  const firstOpenRequests = await collectSearchRequestNames(page);

  const deepQuery = await runQuery(page, 'assertions');
  const deepQueryRequests = await collectSearchRequestNames(page);

  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.evaluate(() => {
    performance.clearResourceTimings?.();
  });

  const warmOpenMs = await openSearch(page);
  const warmOpenRequests = await collectSearchRequestNames(page);
  const unicodeQuery = await runQuery(page, 'Пример');
  const unicodeQueryRequests = await collectSearchRequestNames(page);

  await context.close();

  return {
    id: scenario.id,
    cpuThrottlingRate: scenario.cpuThrottlingRate,
    firstOpenMs,
    firstOpenRequests,
    deepQuery: {
      ...deepQuery,
      requests: deepQueryRequests,
    },
    warmOpenMs,
    warmOpenRequests,
    unicodeQuery: {
      ...unicodeQuery,
      requests: unicodeQueryRequests,
    },
  };
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const results = [];
    for (const scenario of scenarios) {
      results.push(await profileScenario(browser, scenario));
    }

    const report = {
      generatedAt: new Date().toISOString(),
      url,
      scenarios: results.map((scenario) => ({
        ...scenario,
        firstOpenRequests: filterSearchRequests(scenario.firstOpenRequests),
        warmOpenRequests: filterSearchRequests(scenario.warmOpenRequests),
        deepQuery: {
          ...scenario.deepQuery,
          requests: filterSearchRequests(scenario.deepQuery.requests),
        },
        unicodeQuery: {
          ...scenario.unicodeQuery,
          requests: filterSearchRequests(scenario.unicodeQuery.requests),
        },
      })),
    };

    fs.writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`);
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE

echo "Search profile report: $REPORT_FILE"
