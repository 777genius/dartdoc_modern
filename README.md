# dartdoc-vitepress

> Fork of [dart-lang/dartdoc](https://github.com/dart-lang/dartdoc) with **modern docs backends** for generating polished API documentation as either a VitePress site or a Jaspr content site instead of default HTML.

## What's different from dartdoc?

| Feature | dartdoc | dartdoc-vitepress |
|---|---|---|
| Output format | Static HTML | `--format html|vitepress|jaspr` |
| Search | Built-in (basic) | VitePress local search, Jaspr staged local search |
| Theming | CSS customization | VitePress theme or Jaspr `ContentTheme` presets |
| Guide docs | Not supported | Auto-discovers `doc/` & `docs/` files |
| Workspace mode | Not supported | `--workspace-docs` for mono-repos |
| Sidebar | HTML nav | Auto-generated TS or Dart sidebar data |
| Customization | Templates | Open markdown output + scaffold you can extend |

The fork adds `--format vitepress` and `--format jaspr` while keeping backward compatibility with the original `dart doc` HTML output.

## Why People Care

- modern docs UX without giving up `dartdoc`'s analyzer-driven API model
- one generator, multiple outputs
- VitePress for ecosystem-first teams
- Jaspr for Dart-first teams
- real guide support, not only API pages
- credible large-project story, not just toy-package screenshots

## Best Fit

Choose `vitepress` when:
- you want the strongest static-site ecosystem
- your team is already comfortable with Vue, VitePress, and Node-based docs tooling

Choose `jaspr` when:
- you want a Dart-native docs application
- you want typed generated data and theming closer to the Dart toolchain
- you want to extend docs UI without dropping into Vue/TypeScript

## Installation

```bash
# From pub.dev
dart pub global activate dartdoc_vitepress
```

## Quick Start

```bash
# Generate VitePress docs for a single package
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format vitepress \
  --output docs-site

# Generate Jaspr docs for a single package
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format jaspr \
  --output docs-site

# Preview VitePress
cd docs-site && npm install && npx vitepress dev

# Build Jaspr output
cd docs-site && dart pub get && dart run build_runner build --delete-conflicting-outputs
```

## Why Two Backends

- `vitepress` is the best fit when you want the VitePress ecosystem, Vue-level theme control, and the strongest existing static-site workflow.
- `jaspr` is the best fit when you want a Dart-native docs application with typed sidebar data, `jaspr_content` theming, runtime theme switching, and a scaffold your Flutter/Dart team can extend without leaving Dart.

## Jaspr Feature Parity

The `jaspr` backend is not a bare markdown dump. It carries over the strongest UX features from the VitePress backend:

- SPA-style navigation with client-side transitions
- local search with staged loading for large docs sites
- theme toggle with persisted light/dark preference
- API breadcrumbs and right-side outline
- API auto-linking for inline code references
- DartPad embeds from fenced code blocks
- Mermaid diagrams
- build-time `<<<` code import expansion for guides
- generated Dart sidebar data instead of TypeScript strings

The current Jaspr scaffold follows `jaspr_content` best practices:

- `ContentTheme` as the base theme layer
- runtime `ThemeToggle`
- semantic docs-shell tokens for custom UI
- preset-driven theming via `DocsThemePreset`

See:
- [Jaspr Theming](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-theming.md)
- [Jaspr Search Verification](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-search-verification.md)
- [Jaspr Community Showcase](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-community-showcase.md)
- [Jaspr Public Demo Checklist](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-public-demo.md)
- [Jaspr vs VitePress](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-vs-vitepress.md)
- [Jaspr Launch Checklist](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-checklist.md)
- [Jaspr Launch Readiness](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-readiness.md)
- [Jaspr Reddit Draft](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-reddit-post.md)
- [Jaspr Demo Script](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-demo-script.md)
- [Jaspr Post Assets](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-post-assets.md)

## How it works

```
Dart source -> [analyzer] -> PackageGraph -> [GeneratorBackend] -> format-specific scaffold
```

1. **API docs** — each library, class, function, property becomes markdown under `content/api` or `api`
2. **Guide docs** — markdown files from `doc/` or `docs/` are copied to `content/guide` or `guide`
3. **Scaffold files** — backend-specific app shell is generated around that markdown
4. **Sidebar data** — VitePress gets TypeScript data, Jaspr gets typed Dart data

### Generated structure

#### VitePress

```
docs-site/
├── .vitepress/
│   ├── config.ts                 # Your customizable config (created once)
│   └── generated/
│       ├── api-sidebar.ts        # Auto-generated API sidebar
│       └── guide-sidebar.ts      # Auto-generated guide sidebar
├── api/                          # Auto-generated API markdown
│   ├── index.md
│   ├── my_package/
│   │   ├── MyClass-class.md
│   │   └── ...
│   └── ...
├── guide/                        # Copied from doc/ & docs/ directories
│   ├── index.md                  # Created once (customizable)
│   └── my-guide.md
├── index.md                      # Landing page (created once)
└── package.json                  # VitePress dependency (created once)
```

#### Jaspr

```
docs-site/
├── content/
│   ├── api/                      # Auto-generated API markdown
│   ├── guide/                    # Copied from doc/ & docs/ directories
│   └── index.md
├── lib/
│   ├── app.dart                  # Shared app builder
│   ├── main.server.dart          # Server entrypoint
│   ├── main.client.dart          # Client entrypoint
│   ├── generated/
│   │   ├── api_sidebar.dart      # Auto-generated typed sidebar data
│   │   └── guide_sidebar.dart
│   ├── layouts/
│   ├── components/
│   └── theme/
├── web/
│   ├── index.html
│   └── generated/
│       ├── api_styles.css
│       ├── search_index.json
│       ├── search_pages.json
│       ├── search_sections.json
│       └── search_sections_content.json
└── pubspec.yaml
```

## Community Preview

If you want the shortest path to evaluating the Jaspr backend before showing it publicly, start here:

- [Jaspr Public Demo Checklist](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-public-demo.md)
- [Jaspr Search Verification](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-search-verification.md)
- [Jaspr Theming](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-theming.md)
- [Jaspr Launch Readiness](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-readiness.md)
- [Jaspr Reddit Draft](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-reddit-post.md)

## CI/CD with GitHub Pages

Add to `.github/workflows/docs.yml`:

```yaml
name: Deploy Documentation

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: docs-site/package-lock.json

      - name: Install dartdoc-vitepress
        run: dart pub global activate dartdoc_vitepress

      - name: Generate API docs
        run: dart pub global run dartdoc_vitepress --format vitepress --output docs-site

      - run: npm ci
        working-directory: docs-site

      - run: npx vitepress build
        working-directory: docs-site

      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: docs-site/.vitepress/dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    permissions:
      pages: write
      id-token: write
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Don't forget: **Settings → Pages → Source: GitHub Actions**.

For Jaspr, the generated site is a Dart app rather than a Node/Vite app. The simplest public-preview path is:

1. generate the Jaspr scaffold with `--format jaspr`
2. run `dart pub get`
3. run `dart run build_runner build --delete-conflicting-outputs`
4. deploy the generated static output for your chosen Jaspr hosting workflow

## Key CLI options

| Option | Description |
|---|---|
| `--format vitepress` | Generate VitePress markdown instead of HTML |
| `--format jaspr` | Generate a Jaspr content site instead of HTML |
| `--workspace-docs` | Document all packages in a Dart workspace |
| `--exclude-packages 'a,b,c'` | Skip specific packages |
| `--output <dir>` | Output directory (default: `doc/api`) |
| `--guide-dirs 'doc,docs'` | Directories to scan for guide markdown (default: `doc,docs`) |

All original dartdoc options (`--exclude`, `--include`, `--header`, etc.) are still supported.

## Extensible Plugin Architecture

The generated site is a standard VitePress project — you can add custom markdown-it plugins, Vue components, and CSS to extend functionality beyond what dartdoc provides.

### Bundled plugin examples

These are not part of the generator itself, but patterns you can add to `docs-site/.vitepress/theme/plugins/`:

#### API Auto-linker

A markdown-it plugin that scans the generated `api/` directory at build time and automatically converts inline code references in guide pages to clickable links pointing to API docs.

Write `` `ModuleScope` `` in your guide — it renders as a styled link to `/api/your_package/ModuleScope`. Handles dotted access (`` `Modularity.observer` ``), generics (`` `ModuleScope<Auth>` ``), and skips Dart/Flutter built-in types.

```ts
// .vitepress/theme/plugins/api-linker.ts
// Scans api/ at init, builds symbol map, transforms code_inline tokens
md.use(apiLinkerPlugin)
```

#### Interactive DartPad Embeds

A markdown-it plugin + Vue component that turns ` ```dartpad ` code fences into interactive playgrounds with syntax highlighting, a "Run" button, and a DartPad iframe — all without leaving the docs page.

````markdown
```dartpad height=400 mode=flutter
import 'package:flutter/material.dart';
void main() => runApp(const Text('Hello'));
```
````

#### API Breadcrumbs

A Vue component (`<ApiBreadcrumb />`) auto-injected into API pages.
Renders `package > category` navigation from the route path and frontmatter.

### Why this matters

Standard dartdoc generates closed HTML output.
dartdoc-vitepress generates **open markdown + TypeScript data**
that you can extend:

- **Custom plugins** — `md.use(yourPlugin)` in `config.ts`
- **Vue components** — register in `theme/index.ts`, use in `.md`
- **Theme customization** — `custom.css` or full theme override
- **Data transforms** — import `api-sidebar.ts` or scan `api/`

## Build Optimization for Large Sites

For typical packages (20–200 API pages), the default config works out of the box. For very large projects (1,000+ pages, e.g. Dart SDK with ~1,800 pages), the VitePress build may run out of memory. The following settings in `.vitepress/config.ts` and `package.json` resolve this:

```ts
// .vitepress/config.ts
export default defineConfig({
  // Limit concurrent page rendering (default: 64).
  // Lower values reduce peak memory at the cost of slower builds.
  buildConcurrency: 8,

  // Extract page metadata into a shared JS chunk instead of
  // inlining the hash map in every HTML file.
  metaChunk: true,

  vite: {
    build: {
      // Disable source maps to reduce memory usage.
      sourcemap: false,
      // Disable Rollup's module cache so GC can free AST data
      // between modules. Trades speed for lower memory.
      rollupOptions: {
        cache: false,
      },
    },
  },
  // ...
})
```

```json
// package.json — increase Node.js heap limit
{
  "scripts": {
    "build": "NODE_OPTIONS='--max-old-space-size=24576' vitepress build"
  }
}
```

| Option | What it does | Trade-off |
|---|---|---|
| `buildConcurrency: 8` | Renders 8 pages at a time instead of 64 | Slower for small sites |
| `metaChunk: true` | Shared metadata chunk | Extra HTTP request on first load |
| `sourcemap: false` | No source maps in production | Harder to debug production issues |
| `rollupOptions.cache: false` | Frees AST memory between modules | Slower bundling |
| `--max-old-space-size=24576` | 24 GB JS heap (needs 32 GB RAM) | Not available on all machines |

For CI/CD (GitHub Actions standard runner has ~7 GB RAM), use `--max-old-space-size=7168` and consider a self-hosted runner for very large sites.

## Large-Project Verification

The Jaspr backend has been exercised against a real large Flutter workspace:

- source: `/Users/belief/dev/projects/headless/packages/headless`
- result: `206` public libraries, `5701` generated pages, `0` errors
- output: staged search with:
  - manifest: `226 B`
  - pages: `1.8 MB`
  - section metadata: `5.2 MB`
  - section content: `23 MB`

That staged search shape matters because it keeps first-open search light even on very large docs sets while preserving deeper section-level search.

## Roadmap / Known Differences

- **Member pages are inline.** Class members (constructors, methods, properties, operators) are rendered as sections on the class page rather than as separate subpages (unlike api.dart.dev which creates individual pages like `/dart-core/Uri/toString.html`). This produces ~1,800 files for the Dart SDK instead of ~15,000+, resulting in faster builds and lower memory usage. Separate member pages may be added in a future release.
- **Jaspr search is staged, not Algolia/Pagefind-backed.** The current design is fully local and static-host friendly. It already performs well on large Flutter workspaces, but public browser-level tuning can still improve the final “instant” feel on extremely large sites.

## Upstream

Based on [dart-lang/dartdoc v9.0.5-wip](https://github.com/dart-lang/dartdoc) and synced through commit `1c367092`.

The VitePress backend is implemented as an additional `GeneratorBackend`, not a replacement — the original HTML generation is fully intact.

## License

Same as [dartdoc](https://github.com/dart-lang/dartdoc/blob/main/LICENSE) — BSD-3-Clause.
