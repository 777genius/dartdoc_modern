---
sidebar_position: 5
---

# Benchmark: dart doc vs dartdoc-modern

Comparison of documentation generation speed across all backends:
standard `dart doc`, and `dartdoc-modern` in HTML, VitePress, and Jaspr modes -
both in JIT and AOT execution.

## Test Setup

| Parameter | Value |
|---|---|
| Package | `headless_contracts` (Flutter headless UI component contracts) |
| Dart files | 87 source files |
| Public libraries | 12 |
| Elements precached | 666,225 |
| Resolved libraries | 959 (including transitive Flutter SDK) |
| Machine | macOS, Apple Silicon |
| Dart SDK | 3.10.7 |
| Execution | Sequential, single-threaded, no parallel load |

## Results

### Generation Time

| Generator | AOT | JIT (`dart run`) | Speedup |
|---|---|---|---|
| `dart doc` (standard) | **15.4 s** | - | baseline |
| `dartdoc-modern --format html` | **20.0 s** | 52.4 s | 2.6x |
| `dartdoc-modern --format vitepress` | **18.6 s** | 63.5 s | 3.4x |
| `dartdoc-modern --format jaspr` | **19.1 s** | 48.0 s | 2.5x |

**Why these speeds:**

- **85% of the time is `buildPackageGraph`** - the shared dartdoc core that
  runs the Dart analyzer, resolves types, and links all 666k elements. This
  phase is identical for all backends. The actual generation code (rendering
  pages, writing files) takes only 1-3 seconds regardless of format.
- **JIT is 2.5-3.4x slower than AOT** because `dart run` compiles Dart source
  to machine code at runtime (JIT warmup), while AOT (`dart compile exe`) and
  the SDK's built-in `dart doc` use pre-compiled native code that starts
  instantly.
- **Format differences are negligible.** HTML: 1.1s, VitePress: 1.6s, Jaspr:
  3.1s of actual generation work. The rest is the analyzer.

### Generated Output Size (before build)

| Format | Disk Size | Files | Why |
|---|---|---|---|
| dart doc HTML | 9.9 MB | 1,158 | Separate HTML page per method/property (866 member pages + 120 class pages + index pages). Each page is lightweight (5 KB avg) with minimal JS/CSS. |
| dartdoc-modern HTML | 10 MB | 1,159 | Same as dart doc - uses the same HTML templates. |
| dartdoc-modern VitePress | 2.0 MB | 177 | Markdown only. All class members are inlined on the class page, so ~7x fewer files. No JS/CSS yet - just content. |
| dartdoc-modern Jaspr | 3.4 MB | 270 | Markdown content (153 files) + generated Dart source code (103 files for components, sidebar, routes). Larger than VitePress because it includes typed Dart code that will be compiled during build. |

**Why VitePress/Jaspr have fewer files:** Standard dartdoc creates a **separate
page for every method, property, and constructor** (866 pages for members
alone). VitePress and Jaspr embed all members on the parent class page, reducing
the page count from 1,147 to ~160.

### Final Build Output

VitePress and Jaspr require a build step to produce the deployable static site.
HTML formats are ready to serve immediately.

| Step | VitePress | Jaspr |
|---|---|---|
| Build command | `npx vitepress build` | `jaspr build` |
| Build time | **9.1 s** | **12.9 s** |
| Final output size | 24 MB (503 files) | 44 MB (478 files) |
| **Total (AOT generate + build)** | **27.7 s** | **32.0 s** |

**Why VitePress is 24 MB (larger than dart doc's 9.9 MB):**

VitePress produces a Vue SPA with SSR pre-rendering. The 24 MB breaks down as:

| Component | Size | Why |
|---|---|---|
| Pre-rendered HTML | 15.7 MB (161 pages x 100 KB) | Each page contains the full pre-rendered content plus Vue hydration metadata. Pages are ~20x heavier than dart doc's 5 KB pages because they include SSR markup for client-side hydration. |
| Per-page JS chunks | 4.8 MB (320 files) | VitePress generates a lazy-loaded JS chunk for **each page** for SPA navigation. When you click a link, the browser loads the chunk instead of a full page reload. This is the SPA trade-off: faster navigation, but more total bytes. |
| Vue framework | 1.3 MB (4 files) | Vue runtime, VitePress theme, search plugin. Fixed cost regardless of page count. |
| Fonts + CSS | 0.2 MB | Shared assets. |

**Why Jaspr is 44 MB (the largest):**

Jaspr compiles the entire Dart web app to JS and pre-renders all routes via SSR:

| Component | Size | Why |
|---|---|---|
| Pre-rendered HTML | 36.3 MB (154 pages x 241 KB) | The heaviest per-page HTML. Each page is a complete server-side rendered DOM with Jaspr hydration markers, inline styles, and full component tree. ~50x heavier than dart doc's minimal HTML. |
| dart2js output | 1.9 MB (19 files) | The compiled Dart app - Jaspr runtime, routing, markdown renderer, search, syntax highlighting. Fixed cost that does not grow with page count. |
| Search index + data | 0.6 MB | JSON manifests for client-side search. |

### Scaling Prediction

For **large projects** (hundreds of classes, thousands of members), the ratio
shifts in favor of VitePress/Jaspr:

- **dart doc HTML** scales linearly: every new method = +1 page (+5 KB).
  A project with 10,000 members = ~50 MB of HTML.
- **VitePress** scales more slowly: members are inlined, so a new method only
  adds content to an existing class page. The fixed overhead (1.3 MB framework +
  per-page JS chunks) grows slower than dart doc's per-member pages.
- **Jaspr** has the highest fixed cost (~2.5 MB dart2js + runtime) but scales
  the slowest for page count, since members are inlined. For very large projects,
  the per-page HTML overhead dominates, but the total file count stays low.

At roughly **500+ classes**, VitePress should be smaller than dart doc HTML in
total output. The cross-over point for Jaspr is higher due to heavier per-page
HTML, but file count stays manageable.

## AOT Compilation

`dartdoc-modern` supports AOT compilation via `dart compile exe`:

```bash
# Build the AOT binary
dart compile exe bin/dartdoc_vitepress.dart -o dartdoc_modern

# Run with DARTDOC_MODERN_ROOT pointing to the source tree
export DARTDOC_MODERN_ROOT=/path/to/dartdoc-vitepress
export FLUTTER_ROOT=/path/to/flutter  # for Flutter packages
./dartdoc_modern --format jaspr --output docs-site
```

**Why DARTDOC_MODERN_ROOT is needed:** AOT binaries cannot resolve `package:`
URIs at runtime (`Isolate.resolvePackageUri` returns null in AOT). The env
variable tells the binary where to find scaffold templates (VitePress/Jaspr
config files, themes, etc.). If not set, the binary tries to auto-detect via
`.dart_tool/package_config.json` near the executable or working directory.

> **Note:** AOT mode does not currently work with `--sdk-docs` because the Dart
> SDK internal paths are resolved differently in AOT. Use JIT for SDK
> documentation.

### CI/CD Usage

```yaml
# GitHub Actions example
- name: Build dartdoc-modern AOT
  run: dart compile exe bin/dartdoc_vitepress.dart -o /tmp/dartdoc_modern

- name: Generate docs
  env:
    DARTDOC_MODERN_ROOT: ${{ github.workspace }}/dartdoc-vitepress
    FLUTTER_ROOT: ${{ env.FLUTTER_HOME }}
  run: /tmp/dartdoc_modern --format jaspr --output docs-site
```

## What Each Format Produces

**HTML** (dart doc / dartdoc-modern):
- Ready-to-serve static HTML files - no build step
- One page per class, method, property, constructor
- Lightweight pages (~5 KB) with embedded navigation
- Standard dartdoc styling

**VitePress**:
- Markdown files with YAML frontmatter
- All members inlined on class pages (fewer, richer pages)
- Requires `npx vitepress build` to produce final site
- Build produces a Vue SPA with SSR pre-rendering and per-page lazy JS chunks
- Vue-powered extensibility (custom components, plugins)

**Jaspr**:
- Dart web application (pubspec.yaml, lib/, web/, content/)
- Typed Dart components for every API page
- Requires `jaspr build` to produce final site
- Build compiles Dart to JS and pre-renders all routes via SSR
- Full Dart-native theming and layout system

## Reproducing the Benchmark

```bash
cd your-flutter-package/

# Standard dartdoc (uses SDK's AOT snapshot)
time dart doc --output /tmp/bench-std

# dartdoc-modern via JIT
time dart run dartdoc_modern --format html --output /tmp/bench-jit-html
time dart run dartdoc_modern --format vitepress --output /tmp/bench-jit-vp
time dart run dartdoc_modern --format jaspr --output /tmp/bench-jit-jaspr

# dartdoc-modern via AOT (compile once, run fast)
dart compile exe /path/to/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  -o /tmp/dartdoc_modern
export DARTDOC_MODERN_ROOT=/path/to/dartdoc-vitepress
export FLUTTER_ROOT=/path/to/flutter
time /tmp/dartdoc_modern --format html --output /tmp/bench-aot-html
time /tmp/dartdoc_modern --format vitepress --output /tmp/bench-aot-vp
time /tmp/dartdoc_modern --format jaspr --output /tmp/bench-aot-jaspr
```

Add `--show-stats` for detailed phase breakdown:

```
Runtime performance:
generateDocs                     19100ms
  buildPackageGraph              15200ms
    getLibraries                 12800ms
    initializePackageGraph        2400ms
  generator.generate              1900ms
  validateLinks                   2000ms
```

## Conclusion

### Full Pipeline Summary

| Format | Generate (AOT) | Build | Total | Deploy Size |
|---|---|---|---|---|
| dart doc HTML | 15.4 s | - | **15.4 s** | 9.9 MB |
| dartdoc-modern HTML | 20.0 s | - | **20.0 s** | 10 MB |
| dartdoc-modern VitePress | 18.6 s | 9.1 s | **27.7 s** | 24 MB |
| dartdoc-modern Jaspr | 19.1 s | 12.9 s | **32.0 s** | 44 MB |

The deploy sizes are counterintuitive: VitePress (24 MB) and Jaspr (44 MB) are
**larger** than dart doc HTML (9.9 MB) for this small package. This is because
the fixed overhead (Vue framework, dart2js runtime, SSR hydration markup)
dominates when there are few pages. For larger projects with hundreds of classes,
the per-member page multiplication in dart doc HTML catches up and eventually
exceeds VitePress/Jaspr.

With AOT compilation, dartdoc-modern generation runs at **18-20 seconds** -
within 20-30% of standard `dart doc`. The build step adds 9-13 seconds,
bringing the full pipeline to under 35 seconds.

Choose your format based on your needs, not speed:
- **HTML** for zero-config static API docs (15-20s, ready to serve)
- **VitePress** for the richest static-site ecosystem with Vue extensibility (~28s total)
- **Jaspr** for a fully Dart-native documentation application (~32s total)
