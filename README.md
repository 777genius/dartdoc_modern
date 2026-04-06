# dartdoc_modern

[![pub package](https://img.shields.io/pub/v/dartdoc_modern.svg)](https://pub.dev/packages/dartdoc_modern)

> Fork of [dart-lang/dartdoc](https://github.com/dart-lang/dartdoc) with modern docs backends for generating polished API documentation as either a Jaspr docs app or a VitePress site instead of default HTML.

## Status

- `jaspr`: default modern backend for teams that want a Dart-native docs app scaffold
- `vitepress`: mature alternative for teams that want the strongest static-site ecosystem
- `html`: original `dartdoc` output remains available for compatibility

This project is already good enough to show publicly and collect feedback from real Dart and Flutter package maintainers.

Live docs:
- [Jaspr version](https://777genius.github.io/dartdoc_modern/jaspr/)
- [VitePress version](https://777genius.github.io/dartdoc_modern/vitepress/)

## Why This Exists

Default `dartdoc` HTML is useful, but many teams want a documentation site that feels more like a modern product docs experience:
- better search
- guide pages next to API pages
- clearer navigation and breadcrumbs
- theming that does not feel like an afterthought
- a scaffold they can actually extend

`dartdoc_modern` keeps `dartdoc`'s analyzer-driven API model and adds multiple output backends on top of it.

## What Is Different From dartdoc?

| Feature | dartdoc | dartdoc_modern |
|---|---|---|
| Output format | Static HTML | `--format html|jaspr|vitepress` |
| Search | Built-in (basic) | VitePress local search, Jaspr staged local search |
| Guide docs | Not supported | Auto-discovers `doc/` and `docs/` |
| Workspace mode | Not supported | `--workspace-docs` for mono-repos |
| Build speed / file count | Many HTML pages | Much faster, far fewer generated files |
| Sidebar data | HTML nav | Generated TS or typed Dart data |
| Theming | CSS customization | VitePress theme or Jaspr `ContentTheme` presets |
| Extensibility | HTML templates | Open markdown output plus scaffold you can extend |

The speedup comes from page strategy, not from cutting features.

Standard `dartdoc` creates a separate HTML page for every single member. Every method, property, constructor, and constant gets its own page with full HTML chrome around it. `dartdoc_modern` keeps members inline on the type or library page instead.

To put that in perspective:
- Flutter `Icons` has roughly 2,000 static constants. `dartdoc` turns that into about 2,001 pages for one class. `dartdoc_modern` keeps it on one page.
- The full Dart SDK with `dartdoc` is roughly 15,000+ HTML files. `dartdoc_modern` is about 1,800 markdown files, around 52 MB of source markdown.
- Packages like `material_design_icons_flutter` with 7,000+ static const icons become 7,000+ pages in standard `dartdoc`, but a single page in `dartdoc_modern`.

This is deliberate. It cuts file-system churn and I/O, which makes builds much faster, and it is also a better browsing model for developers: you can search within the whole class, jump with the outline, and use full-text search without opening dozens of tiny member pages.

## Which Backend Should You Choose?

Choose `jaspr` when:
- you want a Dart-native docs application
- you want typed generated sidebar data and theming closer to the Dart toolchain
- you want the default `dartdoc_modern` path today
- you want to extend the docs shell without dropping into Vue or TypeScript

Choose `vitepress` when:
- you want the strongest static-site ecosystem
- your team already works comfortably with Vue, VitePress, and Node tooling
- you want the lowest-risk path to a polished docs site today

The honest framing is:
- `jaspr` is the Dart-first backend
- `vitepress` is the ecosystem-first backend

That message is stronger and more credible than pretending one output replaces the other for everyone.

## Installation

If you want to use the tool as a normal package consumer:

```bash
dart pub global activate dartdoc_modern
```

This package exposes both:
- `dartdoc_modern`
- `dartdoc_vitepress` (legacy alias)
- `dartdoc`

For public examples and support requests, prefer `dartdoc_modern` in docs and snippets so it is obvious that the multi-backend fork is being used.

## Quick Start

`Jaspr` is the default modern path. `VitePress` remains available when you specifically want the Vue/VitePress ecosystem.

### Using The Installed Package

```bash
# One-time install for local Jaspr preview/build
dart pub global activate jaspr_cli

# Default modern path: generate and preview Jaspr docs
dartdoc_modern --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve

# Alternative static-site path: generate and preview VitePress docs
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```

### Package Maintainer Recipes

Start with the Jaspr recipe unless you specifically want the VitePress ecosystem.

#### Jaspr Recipe (Default)

```bash
dart pub global activate jaspr_cli
dartdoc_modern --format jaspr --output docs-site
cd docs-site
dart pub get
jaspr serve
```

For deployment:

```bash
cd docs-site
jaspr build --dart-define DOCS_THEME=ocean
```

Deploy:
- `docs-site/build/jaspr`

#### VitePress Recipe

```bash
dartdoc_modern --format vitepress --output docs-site
cd docs-site
npm install
npx vitepress build
```

Deploy:
- `docs-site/.vitepress/dist`

Run the strongest package-level release gate before posting or publishing:

```bash
dart run tool/task.dart validate package-release
```

### Using The Local Source

Use the local source while evaluating or developing the project:

```bash
# Generate and preview Jaspr docs for a single package
dart run ./bin/dartdoc_modern.dart \
  --format jaspr \
  --output docs-site
cd docs-site && dart pub get && jaspr serve

# Generate and preview VitePress docs for a single package
dart run ./bin/dartdoc_modern.dart \
  --format vitepress \
  --output docs-site
cd docs-site && npm install && npx vitepress dev
```

### Workspace Example

```bash
dart pub global activate jaspr_cli
dart run /path/to/dartdoc_modern/bin/dartdoc_modern.dart \
  --format jaspr \
  --workspace-docs \
  --exclude-packages 'package_a,package_b' \
  --output docs-site
```

Preview Jaspr output:

```bash
cd docs-site && dart pub get && jaspr serve
```

Build Jaspr for deployment:

```bash
cd docs-site && jaspr build --dart-define DOCS_THEME=ocean
```

Preview VitePress instead:

```bash
dart run /path/to/dartdoc_modern/bin/dartdoc_modern.dart \
  --format vitepress \
  --workspace-docs \
  --exclude-packages 'package_a,package_b' \
  --output docs-site
cd docs-site && npm install && npx vitepress dev
```

## Fastest Way To Evaluate The Jaspr Backend

If you only want the shortest serious evaluation path, run the launch gate:

```bash
dart run ./tool/task.dart validate jaspr-launch
```

If Playwright is installed outside `/tmp/pw-run`, set `PLAYWRIGHT_DIR` explicitly.

That single command now checks the practical quality bar for a community-facing Jaspr preview:
- scaffold generation and buildability
- theme and preview flow
- browser route and navigation smoke
- subpath/base-path deploy smoke
- search performance smoke

If you want the stricter release-facing gate before a public post or publish attempt, run:

```bash
dart run ./tool/task.dart validate jaspr-release
```

That adds:
- repo-wide `dart analyze --fatal-infos`
- `dart pub publish --dry-run`
- the full `jaspr-launch` browser and build checks

If you want the broader package-wide gate before a release that should represent
both modern backends, run:

```bash
dart run ./tool/task.dart validate package-release
```

That adds:
- the full `jaspr-release` gate
- the full `vitepress` end-to-end smoke suite

## Why The Jaspr Backend Is Interesting

The `jaspr` backend is not a bare markdown dump. It generates a real Jaspr docs application scaffold with the strongest UX ideas carried over from the VitePress backend.

Current Jaspr capabilities:
- SPA-style navigation feel
- staged local search for API docs and guides
- persisted light and dark theme toggle
- breadcrumbs and right-side outline
- API auto-linking for inline code references
- DartPad embeds
- Mermaid diagrams
- build-time `<<<` code import expansion for guides
- generated typed Dart sidebar data instead of TypeScript strings
- preset-driven theming on top of `jaspr_content`

## How It Works

```text
Dart source -> analyzer -> PackageGraph -> GeneratorBackend -> format-specific scaffold
```

1. API docs become markdown pages under `api/` or `content/api/`
2. Guide docs from `doc/` and `docs/` become `guide/` or `content/guide/`
3. A backend-specific scaffold is generated around those pages
4. Navigation, search, and theme assets are generated for the selected backend

## Generated Structure

### Jaspr

```text
docs-site/
├── content/
│   ├── api/
│   ├── guide/
│   └── index.md
├── lib/
│   ├── app.dart
│   ├── main.server.dart
│   ├── main.client.dart
│   ├── generated/
│   │   ├── api_sidebar.dart
│   │   └── guide_sidebar.dart
│   ├── layouts/
│   ├── components/
│   └── theme/
├── web/
│   ├── index.html
│   └── generated/
└── pubspec.yaml
```

### VitePress

```text
docs-site/
├── .vitepress/
│   ├── config.ts
│   └── generated/
│       ├── api-sidebar.ts
│       └── guide-sidebar.ts
├── api/
├── guide/
├── index.md
└── package.json
```

## Real Proof, Not Just Toy Screenshots

The Jaspr backend has been verified on a real Flutter workspace:
- package root: a production-style `headless` workspace used as a large-project proof run
- `206` public libraries
- `5701` generated files
- `0` errors in the verified run

That does not mean “done forever”, but it does mean this is well beyond a toy-package-only prototype.

## CI/CD Example For Jaspr

For a static Jaspr deployment to GitHub Pages, generate the scaffold, build it,
and upload `build/jaspr`.

### Root Hosting

Use this when the deployed site lives at the domain root.

```yaml
name: Deploy Jaspr Docs

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

      - name: Activate Jaspr CLI
        run: dart pub global activate jaspr_cli

      - name: Generate Jaspr docs
        run: dart run ./bin/dartdoc_modern.dart --format jaspr --output docs-site

      - name: Build static Jaspr site
        run: |
          dart pub get
          jaspr build --dart-define DOCS_THEME=ocean
        working-directory: docs-site

      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: docs-site/build/jaspr

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

### Project Site Or Any Subpath Hosting

Use this when the deployed site lives under a path prefix like
`https://example.github.io/my-package-docs/`.

```yaml
- name: Build static Jaspr site
  run: |
    dart pub get
    jaspr build \
      --dart-define DOCS_THEME=graphite \
      --dart-define DOCS_BASE_PATH=/my-package-docs
  working-directory: docs-site
```

## Jaspr Static Deploy Summary

The Jaspr backend generates a real app scaffold that you build and then deploy as static files:

```bash
dartdoc_modern --format jaspr --output docs-site
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build --dart-define DOCS_THEME=ocean
```

Deploy:

```text
docs-site/build/jaspr
```

If the site is hosted under a subpath, add:

```bash
--dart-define DOCS_BASE_PATH=/your-site-path
```

Use `DOCS_BASE_PATH` whenever the generated site is hosted under a subpath
rather than the domain root.

## CI/CD Example For VitePress

A simple GitHub Pages flow can generate docs from the local source checkout instead of relying on a global install:

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

      - name: Generate API docs
        run: dart run ./bin/dartdoc_modern.dart --format vitepress --output docs-site

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

## Key CLI Options

| Option | Description |
|---|---|
| `--format jaspr` | Generate a Jaspr content site instead of HTML |
| `--format vitepress` | Generate VitePress markdown instead of HTML |
| `--workspace-docs` | Document all packages in a Dart workspace |
| `--exclude-packages 'a,b,c'` | Skip specific packages |
| `--output <dir>` | Output directory |
| `--guide-dirs 'doc,docs'` | Directories to scan for guide markdown |

All original dartdoc options such as `--exclude`, `--include`, and `--header` remain available.

## Honest Known Differences

- member docs are still rendered inline on the owning API page rather than split into separate member pages
- Jaspr search is local and staged, not backed by an external hosted service
- public hosted-demo infrastructure is still a presentation task rather than a generator-core task

Those are real limitations, but none of them invalidate the current community-preview quality bar.

## Upstream

Based on [dart-lang/dartdoc v9.0.5-wip](https://github.com/dart-lang/dartdoc) and synced through commit `a57f497a`.

The VitePress and Jaspr outputs are implemented as additional `GeneratorBackend` variants rather than replacing the original HTML generation.

## License

Same as [dartdoc](https://github.com/dart-lang/dartdoc/blob/main/LICENSE): BSD-3-Clause.
