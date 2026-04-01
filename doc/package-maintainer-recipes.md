# Package Maintainer Recipes

Status:
- practical maintainer guide
- backend-neutral

Purpose:
- show the shortest credible path from package source to deployed docs
- keep the choice between `vitepress` and `jaspr` honest and easy

## Choose A Backend

Choose `vitepress` when:
- you want the strongest static-site ecosystem
- your team is comfortable with Node and VitePress
- you want the lower-risk polished path today

Choose `jaspr` when:
- you want a Dart-native docs app scaffold
- you want typed generated sidebar data and Dart-side theming
- you want to extend the docs shell without Vue or TypeScript

Honest framing:
- `vitepress` = ecosystem-first
- `jaspr` = Dart-first

## Recipe 1: VitePress

Generate docs:

```bash
dartdoc_vitepress --format vitepress --output docs-site
```

Preview locally:

```bash
cd docs-site
npm install
npx vitepress dev
```

Build for deploy:

```bash
npx vitepress build
```

Deploy this directory:

```text
docs-site/.vitepress/dist
```

## Recipe 2: Jaspr

Generate docs:

```bash
dartdoc_vitepress --format jaspr --output docs-site
```

Prepare and build:

```bash
cd docs-site
dart pub get
dart pub global activate jaspr_cli
jaspr build --dart-define DOCS_THEME=ocean
```

For subpath hosting:

```bash
jaspr build \
  --dart-define DOCS_THEME=graphite \
  --dart-define DOCS_BASE_PATH=/your-repo-name
```

Deploy this directory:

```text
docs-site/build/jaspr
```

## Before You Post Or Publish

Strongest package-wide gate:

```bash
dart run tool/task.dart validate package-release
```

That covers:
- repo-wide `dart analyze --fatal-infos`
- `dart pub publish --dry-run`
- the full `jaspr-release` gate
- the full `vitepress` end-to-end smoke suite

If Playwright is installed outside `/tmp/pw-run`, set `PLAYWRIGHT_DIR` first.

## If You Are Evaluating The Repo Itself

Use the local source instead of a global install:

```bash
dart run ./bin/dartdoc_vitepress.dart --format vitepress --output docs-site
dart run ./bin/dartdoc_vitepress.dart --format jaspr --output docs-site
```

## Related Docs

- [Project Overview](../)
- [Jaspr Deployment](jaspr-deployment.md)
- [Jaspr Launch Readiness](jaspr-launch-readiness.md)
- [Jaspr vs VitePress](jaspr-vs-vitepress.md)
