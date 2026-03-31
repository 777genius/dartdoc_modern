# Jaspr Public Demo Checklist

Status:
- preview-ready
- community-preview-ready

Purpose:
- provide one reproducible demo flow for showing the `jaspr` backend publicly
- make the smoke path explicit instead of relying on ad-hoc local steps

## Demo Package

Primary demo package:
- `/Users/belief/dev/projects/dartdoc-vitepress/testing/test_package_with_docs`

This package exercises:
- API pages
- guide pages
- sidebar generation
- search index generation
- breadcrumbs
- outline collapse metadata
- API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time code import expansion

## Demo Commands

Generate docs:

```bash
tmpdir=$(mktemp -d /tmp/dartdoc-jaspr-demo.XXXXXX) && \
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format jaspr \
  --input /Users/belief/dev/projects/dartdoc-vitepress/testing/test_package_with_docs \
  --output "$tmpdir"
```

Prepare and build the generated Jaspr app:

```bash
cd "$tmpdir" && \
dart pub get && \
dart analyze && \
dart run build_runner build --delete-conflicting-outputs
```

Run the scaffold smoke checker:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_scaffold_smoke.dart "$tmpdir"
```

Optional search benchmark:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_search_benchmark.dart \
  "$tmpdir/web/generated/search_index.json" \
  Greeter Getting Started Configuration Пример
```

Large real-project proof:

```bash
cd /Users/belief/dev/projects/headless/packages/headless && \
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --format jaspr \
  --auto-include-dependencies \
  --output /tmp/headless-jaspr-docs-demo
```

Optional large-project benchmark:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_search_benchmark.dart \
  /tmp/headless-jaspr-docs-demo/web/generated/search_index.json \
  State Theme Context Build BuildContext Widget
```

## What To Verify Manually

- Search opens with `Ctrl/Cmd+K`
- Search returns API and guide results
- Search highlights matches and supports arrow-key navigation
- `Greeter` API page renders signatures and links
- guide pages render callouts, Mermaid, and DartPad blocks
- breadcrumbs and right-side outline are visible
- internal navigation feels SPA-like instead of full page reloads
- theme toggle persists light/dark preference
- mobile viewport keeps search usable and sidebar navigable

## What To Say In A Public Demo

- `jaspr` is not a markdown export; it is a Dart-native docs application scaffold.
- The same generator now supports `html`, `vitepress`, and `jaspr`.
- VitePress remains the strongest ecosystem-first option.
- Jaspr is the strongest Dart-first option when the team wants typed scaffold code, `jaspr_content` theming, and extension points in Dart instead of TypeScript/Vue.
- The largest UX parity items from VitePress are already covered:
  - search
  - theme switching
  - breadcrumbs
  - outline
  - auto-linked API references
  - DartPad embeds
  - Mermaid
  - code import expansion
- Large-project generation has been verified on `/Users/belief/dev/projects/headless/packages/headless`.

## Current Quality Bar

Ready for:
- Flutter community preview/demo
- serious evaluation by Dart/Flutter teams
- early adopters trying `jaspr` output on real packages

Not yet positioned as:
- final polished 1.0 release
- hosted public demo with browser-regression QA
- fully benchmarked browser-only search feel on extremely large sites

Related docs:
- `/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-vs-vitepress.md`
- `/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-checklist.md`
- `/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-readiness.md`
