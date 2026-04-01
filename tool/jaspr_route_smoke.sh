#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/belief/dev/projects/dartdoc-vitepress"
PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-/tmp/pw-run}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/jaspr-route-smoke}"
PREVIEW_DIR="${PREVIEW_DIR:-$OUTPUT_DIR/preview}"
PORT="${PORT:-4351}"
THEME="${THEME:-ocean}"
BASE_PATH="${BASE_PATH:-}"
REUSE_BUILD="${REUSE_BUILD:-0}"
REPORT_FILE="$OUTPUT_DIR/report.json"

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
BASE_PATH="$(normalize_base_path "$BASE_PATH")"

entry_probe_path="/guide/getting-started/"
if [ -n "$BASE_PATH" ]; then
  entry_probe_path="$BASE_PATH$entry_probe_path"
fi

cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

THEME="$THEME" \
BASE_PATH="$BASE_PATH" \
REUSE_BUILD="$REUSE_BUILD" \
OUTPUT_DIR="$PREVIEW_DIR" \
PORT="$PORT" \
"$ROOT/tool/jaspr_theme_preview.sh" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 120); do
  if curl -sf "http://127.0.0.1:$PORT$entry_probe_path" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -sf "http://127.0.0.1:$PORT$entry_probe_path" >/dev/null 2>&1; then
  echo "Preview did not start. See $LOG_FILE"
  exit 1
fi

PLAYWRIGHT_DIR="$PLAYWRIGHT_DIR" \
PORT="$PORT" \
BASE_PATH="$BASE_PATH" \
REPORT_FILE="$REPORT_FILE" \
node - <<'NODE'
const fs = require('fs');
const path = require('path');
const { chromium } = require(path.join(process.env.PLAYWRIGHT_DIR, 'node_modules/playwright'));

const baseUrl = `http://127.0.0.1:${process.env.PORT}`;
const basePath = normalizeBasePath(process.env.BASE_PATH ?? '');
const entryUrl = `${baseUrl}${resolveSitePath('/guide/getting-started/')}`;
const reportFile = process.env.REPORT_FILE;

function normalizeBasePath(value) {
  if (!value || value === '/') return '';
  return `/${value.replace(/^\/+/, '').replace(/\/+$/, '')}`;
}

function resolveSitePath(value) {
  const pathName = normalizePath(value);
  if (!basePath) return pathName;
  if (pathName === '/') return `${basePath}/`;
  if (pathName.startsWith(`${basePath}/`) || pathName === basePath) return pathName;
  return `${basePath}${pathName}`;
}

function normalizePath(value) {
  if (!value) return '/';
  const pathname = new URL(value, baseUrl).pathname;
  let normalized = pathname.replace(/\/+$/, '');
  if (basePath && (normalized === basePath || normalized.startsWith(`${basePath}/`))) {
    normalized = normalized.slice(basePath.length) || '/';
  }
  return normalized || '/';
}

function ensure(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function waitForRouteIdle(page) {
  await page.waitForFunction(() => {
    const root = document.documentElement;
    return root?.hasAttribute('data-docs-nav-runtime-ready') &&
      !root?.hasAttribute('data-docs-nav-loading');
  }, { timeout: 30000 });
}

async function waitForPath(page, expectedPath) {
  const normalized = normalizePath(expectedPath);
  await page.waitForFunction(({ expected, basePath }) => {
    let actual = window.location.pathname.replace(/\/+$/, '') || '/';
    if (basePath && (actual === basePath || actual.startsWith(`${basePath}/`))) {
      actual = actual.slice(basePath.length) || '/';
    }
    return actual === expected;
  }, { expected: normalized, basePath }, { timeout: 30000 });
  await waitForRouteIdle(page);
}

async function gotoAndSettle(page, url) {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await waitForRouteIdle(page);
}

async function readPrimaryHeading(page) {
  return page.evaluate(() => {
    const node = document.querySelector('.content-header h1, .content h1');
    return node?.textContent?.replace(/\s+/g, ' ').trim() ?? '';
  });
}

async function collectTargetRoutes(page) {
  const payload = await page.evaluate(async (basePath) => {
    const response = await fetch(`${basePath}/generated/search_pages.json`);
    return response.json();
  }, basePath);
  const entries = Array.isArray(payload.entries) ? payload.entries : [];
  const pages = entries.map((entry) => ({
    kind: entry[0],
    title: entry[1],
    url: entry[2],
  }));

  const guideEntries = pages.filter((entry) => entry.kind === 'guide');
  const apiEntries = pages.filter((entry) => entry.kind === 'api');

  const entryGuide = guideEntries.find(
    (entry) => normalizePath(entry.url) === '/guide/getting-started',
  );
  const secondaryGuide = guideEntries.find(
    (entry) =>
      normalizePath(entry.url) !== '/guide/getting-started' &&
      /configuration/i.test(entry.title),
  ) ||
    guideEntries.find(
      (entry) => normalizePath(entry.url) !== '/guide/getting-started',
    );
  const greeterApi = apiEntries.find(
    (entry) =>
      /greeter/i.test(entry.title) ||
      /Greeter/i.test(entry.url),
  ) || apiEntries[0];

  ensure(entryGuide, 'Could not resolve the getting-started guide route.');
  ensure(secondaryGuide, 'Could not resolve a secondary guide route.');
  ensure(greeterApi, 'Could not resolve a representative API route.');

  return {
    entryGuide,
    secondaryGuide,
    greeterApi,
  };
}

function trackPageDiagnostics(page) {
  const consoleErrors = [];
  const pageErrors = [];
  const httpErrors = [];
  const requestFailures = [];

  page.on('console', (message) => {
    if (message.type() === 'error') {
      consoleErrors.push(message.text());
    }
  });
  page.on('pageerror', (error) => {
    pageErrors.push(error.message);
  });
  page.on('response', (response) => {
    const status = response.status();
    const url = response.url();
    if (status < 400) return;
    if (!url.startsWith(baseUrl)) return;
    httpErrors.push({ status, url });
  });
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (!url.startsWith(baseUrl)) return;
    requestFailures.push({
      url,
      failure: request.failure()?.errorText ?? 'unknown',
    });
  });

  return {
    consoleErrors,
    pageErrors,
    httpErrors,
    requestFailures,
  };
}

async function verifyRootEntry(browser, diagnostics) {
  const page = await browser.newPage();
  page.on('console', (message) => {
    if (message.type() === 'error') {
      diagnostics.consoleErrors.push(`[root] ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => {
    diagnostics.pageErrors.push(`[root] ${error.message}`);
  });
  page.on('response', (response) => {
    const status = response.status();
    const url = response.url();
    if (status >= 400 && url.startsWith(baseUrl)) {
      diagnostics.httpErrors.push({ status, url, phase: 'root' });
    }
  });

  const response = await page.goto(`${baseUrl}${resolveSitePath('/')}`, {
    waitUntil: 'domcontentloaded',
    timeout: 30000,
  });
  await page.waitForFunction((basePath) => {
    let actual = window.location.pathname.replace(/\/+$/, '') || '/';
    if (basePath && (actual === basePath || actual.startsWith(`${basePath}/`))) {
      actual = actual.slice(basePath.length) || '/';
    }
    return actual === '/' || actual === '/guide/getting-started';
  }, basePath, { timeout: 30000 });
  const finalPath = normalizePath(page.url());
  if (finalPath == '/guide/getting-started') {
    await waitForRouteIdle(page);
  }
  ensure(
    finalPath === '/' || finalPath === '/guide/getting-started',
    `Expected root preview to stay on "/" or land on "/guide/getting-started", got "${finalPath}".`,
  );
  ensure(
    response && response.status() >= 200 && response.status() < 400,
    `Expected root preview to return a successful response, got ${response?.status()}.`,
  );
  await page.close();
  return {
    finalPath,
  };
}

async function assertThemeTogglePersists(page) {
  const initialTheme = await page.evaluate(
    () => document.documentElement.getAttribute('data-theme') ?? 'light',
  );
  await page.click('[data-docs-theme-toggle]');
  await page.waitForFunction((expected) => {
    const current = document.documentElement.getAttribute('data-theme');
    return current != null && current !== expected;
  }, initialTheme, { timeout: 30000 });

  const toggledTheme = await page.evaluate(
    () => document.documentElement.getAttribute('data-theme') ?? 'light',
  );
  await page.reload({ waitUntil: 'networkidle', timeout: 30000 });
  await waitForRouteIdle(page);
  const persistedTheme = await page.evaluate(
    () => document.documentElement.getAttribute('data-theme') ?? 'light',
  );
  ensure(
    toggledTheme === persistedTheme,
    `Expected theme toggle to persist after reload. Saw ${toggledTheme} then ${persistedTheme}.`,
  );
  return { initialTheme, toggledTheme, persistedTheme };
}

async function assertDesktopScenario(browser, routes) {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
    colorScheme: 'light',
  });
  const page = await context.newPage();
  const diagnostics = trackPageDiagnostics(page);

  await gotoAndSettle(page, entryUrl);

  const theme = await assertThemeTogglePersists(page);

  await page.click(`a.sidebar-link[href="${resolveSitePath(routes.secondaryGuide.url)}"]`);
  await waitForPath(page, routes.secondaryGuide.url);

  const secondaryHeading = await readPrimaryHeading(page);

  await page.click('[data-docs-search-launcher]');
  await page.waitForSelector('[data-docs-search-overlay]:not([hidden])', { timeout: 30000 });
  await page.fill('[data-search-input]', 'Greeter');
  await page.waitForFunction(() => {
    const results = document.querySelectorAll('.docs-search-result');
    if (results.length == 0) return false;
    const status = document.querySelector('.docs-search-status')?.textContent ?? '';
    return /^\d+ result/.test(status.trim());
  }, { timeout: 30000 });

  const apiResult = page.locator('.docs-search-result').filter({
    has: page.locator('.docs-search-title', { hasText: 'Greeter' }),
  }).first();
  await apiResult.click();
  await waitForPath(page, routes.greeterApi.url);

  const apiHeading = await readPrimaryHeading(page);
  const breadcrumbCount = await page
    .locator('.api-breadcrumb .breadcrumb-link, .api-breadcrumb .breadcrumb-current')
    .count();

  await context.close();

  return {
    theme,
    visitedGuidePath: normalizePath(routes.secondaryGuide.url),
    visitedGuideHeading: secondaryHeading?.trim() ?? '',
    visitedApiPath: normalizePath(routes.greeterApi.url),
    visitedApiHeading: apiHeading?.trim() ?? '',
    breadcrumbCount,
    diagnostics,
  };
}

async function assertMobileScenario(browser, routes) {
  const context = await browser.newContext({
    viewport: { width: 430, height: 932 },
    colorScheme: 'light',
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 3,
  });
  const page = await context.newPage();
  const diagnostics = trackPageDiagnostics(page);

  await gotoAndSettle(page, entryUrl);

  await page.click('[data-docs-sidebar-toggle]');
  await page.waitForFunction(
    () => document.body?.classList.contains('sidebar-open') ?? false,
    { timeout: 30000 },
  );
  await page.click(`a.sidebar-link[href="${resolveSitePath(routes.secondaryGuide.url)}"]`);
  await waitForPath(page, routes.secondaryGuide.url);

  const sidebarClosed = await page.evaluate(
    () => !(document.body?.classList.contains('sidebar-open') ?? false),
  );
  ensure(sidebarClosed, 'Expected sidebar drawer to close after mobile navigation.');

  const heading = await readPrimaryHeading(page);

  await context.close();

  return {
    visitedGuidePath: normalizePath(routes.secondaryGuide.url),
    heading: heading?.trim() ?? '',
    diagnostics,
  };
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const diagnostics = {
      consoleErrors: [],
      pageErrors: [],
      httpErrors: [],
    };

    const rootEntry = await verifyRootEntry(browser, diagnostics);

    const routeContext = await browser.newContext({
      viewport: { width: 1440, height: 1100 },
      colorScheme: 'light',
    });
    const routePage = await routeContext.newPage();
    await gotoAndSettle(routePage, entryUrl);
    const routes = await collectTargetRoutes(routePage);
    await routeContext.close();

    const desktop = await assertDesktopScenario(browser, routes);
    const mobile = await assertMobileScenario(browser, routes);

    const allConsoleErrors = [
      ...diagnostics.consoleErrors,
      ...desktop.diagnostics.consoleErrors,
      ...mobile.diagnostics.consoleErrors,
    ];
    const allPageErrors = [
      ...diagnostics.pageErrors,
      ...desktop.diagnostics.pageErrors,
      ...mobile.diagnostics.pageErrors,
    ];
    const allHttpErrors = [
      ...diagnostics.httpErrors,
      ...desktop.diagnostics.httpErrors,
      ...mobile.diagnostics.httpErrors,
    ];
    const allRequestFailures = [
      ...desktop.diagnostics.requestFailures,
      ...mobile.diagnostics.requestFailures,
    ];

    const report = {
      generatedAt: new Date().toISOString(),
      baseUrl,
      basePath,
      routes: {
        entryGuide: normalizePath(routes.entryGuide.url),
        secondaryGuide: normalizePath(routes.secondaryGuide.url),
        greeterApi: normalizePath(routes.greeterApi.url),
      },
      rootEntry,
      desktop: {
        theme: desktop.theme,
        visitedGuidePath: desktop.visitedGuidePath,
        visitedGuideHeading: desktop.visitedGuideHeading,
        visitedApiPath: desktop.visitedApiPath,
        visitedApiHeading: desktop.visitedApiHeading,
        breadcrumbCount: desktop.breadcrumbCount,
      },
      mobile: {
        visitedGuidePath: mobile.visitedGuidePath,
        heading: mobile.heading,
      },
      diagnostics: {
        consoleErrors: allConsoleErrors,
        pageErrors: allPageErrors,
        httpErrors: allHttpErrors,
        requestFailures: allRequestFailures,
      },
    };

    ensure(
      desktop.visitedGuideHeading.toLowerCase().includes('configuration'),
      `Expected desktop sidebar navigation to reach the configuration guide, got "${desktop.visitedGuideHeading}".`,
    );
    ensure(
      /greeter/i.test(desktop.visitedApiHeading),
      `Expected search navigation to reach a Greeter API page, got "${desktop.visitedApiHeading}".`,
    );
    ensure(
      mobile.heading.toLowerCase().includes('configuration'),
      `Expected mobile navigation/search to stay on the configuration guide, got "${mobile.heading}".`,
    );
    ensure(
      desktop.breadcrumbCount > 0,
      'Expected API page to render breadcrumbs after search navigation.',
    );
    ensure(
      allConsoleErrors.length === 0,
      `Browser console errors were captured: ${allConsoleErrors.join(' | ')}`,
    );
    ensure(
      allPageErrors.length === 0,
      `Browser page errors were captured: ${allPageErrors.join(' | ')}`,
    );
    ensure(
      allHttpErrors.length === 0,
      `HTTP errors were captured: ${JSON.stringify(allHttpErrors)}`,
    );
    ensure(
      allRequestFailures.length === 0,
      `Request failures were captured: ${JSON.stringify(allRequestFailures)}`,
    );

    fs.writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`);
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE

echo "Route smoke report: $REPORT_FILE"
