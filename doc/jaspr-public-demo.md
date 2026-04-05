---
internal: true
---

# Jaspr Public Demo Checklist

This page gives one reproducible flow for showing the `jaspr` backend publicly
without overselling it. The goal is simple: make the shortest serious evaluation
path obvious and keep the framing honest.

## Shortest Serious Evaluation Path

Primary public-demo quality gate:

```bash
dart run ./tool/task.dart validate jaspr-launch
```

If Playwright is not installed in `/tmp/pw-run`, export `PLAYWRIGHT_DIR` first.

If that passes, you already have a strong practical signal that the current
Jaspr preview is worth showing.

## Demo Package

Primary demo package:
- `testing/test_package_with_docs`

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

## Manual Flow If You Want To Inspect The Output

Generate docs:

```bash
tmpdir=$(mktemp -d /tmp/dartdoc-jaspr-demo.XXXXXX) && \
dart run ./bin/dartdoc_modern.dart \
  --format jaspr \
  --input ./testing/test_package_with_docs \
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
dart run ./tool/jaspr_scaffold_smoke.dart "$tmpdir"
```

Browser route and navigation smoke:

```bash
dart run ./tool/task.dart validate jaspr-route-smoke
```

Optional search benchmark:

```bash
dart run ./tool/jaspr_search_benchmark.dart \
  "$tmpdir/web/generated/search_index.json" \
  Greeter Getting\ Started Configuration Пример
```

## Large Real-Project Proof

Verified large-project run:

Verified on a large real Flutter workspace (`headless`) with the same pattern:

```bash
dart run ./bin/dartdoc_modern.dart \
  --format jaspr \
  --auto-include-dependencies \
  --output /tmp/headless-jaspr-docs-demo
```

Optional benchmark:

```bash
dart run ./tool/jaspr_search_benchmark.dart \
  /tmp/headless-jaspr-docs-demo/web/generated/search_index.json \
  State Theme Context Build BuildContext Widget
```

## Best Things To Verify Manually

- Search opens with `Ctrl/Cmd+K`
- Search returns both guide and API results
- Search highlights matches and supports arrow-key navigation
- `Greeter` API page renders signatures and links correctly
- guide pages render callouts, Mermaid, and DartPad blocks
- breadcrumbs and right-side outline are visible
- internal navigation feels SPA-like instead of full page reloads
- theme toggle persists light and dark preference
- mobile viewport keeps search usable and sidebar navigable

## Best Community Framing

Use language like:
- `strong community preview`
- `Dart-native docs backend`
- `serious evaluation-ready scaffold`
- `looking for feedback from package maintainers`

Avoid language like:
- `1.0`
- `replacement for every docs stack`
- `finished forever`

## Related Docs

- `doc/jaspr-deployment.md`
- `doc/jaspr-vs-vitepress.md`
- `doc/jaspr-launch-checklist.md`
- `doc/jaspr-launch-readiness.md`
