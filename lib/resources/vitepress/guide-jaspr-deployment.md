---
sidebar_position: 4
---

# Jaspr Deployment

Status:
- practical deployment guide

Purpose:
- explain how to deploy generated Jaspr docs as a real static site
- give one honest path for root hosting and one for subpath hosting

## What The Jaspr Backend Produces

After generation, the output is a real Jaspr app scaffold.

To produce static hosting output, build that app:

```bash
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build
```

Static files are written to:

```text
docs-site/build/jaspr
```

That directory is what you deploy to a static host.

## Root Hosting

If your site will be hosted at the domain root, for example:
- `https://docs.example.dev/`
- `https://my-package.dev/`

then the default build is enough:

```bash
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build --dart-define DOCS_THEME=ocean
```

Deploy:
- `docs-site/build/jaspr`

## Subpath Hosting

If your site will be hosted under a path prefix, for example:
- `https://example.github.io/my-package-docs/`
- `https://company.dev/docs/my-package/`

build with `DOCS_BASE_PATH`:

```bash
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build \
  --dart-define DOCS_THEME=graphite \
  --dart-define DOCS_BASE_PATH=/my-package-docs
```

Important:
- use the full deployed path prefix
- start it with `/`
- do not end it with `/`

Examples:
- good: `/my-package-docs`
- good: `/docs/my-package`
- avoid: `my-package-docs`
- avoid: `/my-package-docs/`

## GitHub Pages

### User or Organization Site

If the site is served from the domain root, you can deploy `build/jaspr` directly without `DOCS_BASE_PATH`.

### Project Site

If the site is served under a repository path, use:

```bash
jaspr build --dart-define DOCS_BASE_PATH=/your-repo-name
```

Then publish:

```text
docs-site/build/jaspr
```

### Example Workflow

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

      - run: dart pub global activate jaspr_cli

      - name: Generate Jaspr docs
        run: dart run ./bin/dartdoc_modern.dart --format jaspr --output docs-site

      - name: Build static Jaspr site
        run: |
          dart pub get
          jaspr build \
            --dart-define DOCS_THEME=graphite \
            --dart-define DOCS_BASE_PATH=/your-repo-name
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
      url: $\{\{ steps.deployment.outputs.page_url \}\}
    permissions:
      pages: write
      id-token: write
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

## Cloudflare Pages, Netlify, Vercel

For any static host, the practical rule is the same:

1. generate the Jaspr scaffold with `--format jaspr`
2. run `dart pub get`
3. run `jaspr build`
4. deploy `build/jaspr`

Only add `DOCS_BASE_PATH` when your deployed URL is not at `/`.

## Recommended Team Recipe

For a package team that wants repeatable docs deploys:

```bash
dartdoc_modern --format jaspr --output docs-site
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build --dart-define DOCS_THEME=forest
```

Then upload:

```text
docs-site/build/jaspr
```

## Related Docs

- `README.md`
- `doc/jaspr-launch-checklist.md`
- `doc/jaspr-public-demo.md`
- `doc/jaspr-theming.md`
- `doc/jaspr-vs-vitepress.md`
