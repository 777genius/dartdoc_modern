# Jaspr Search Verification

Status:
- implemented

Purpose:
- record the Phase 5 search-at-scale verification for the `jaspr` backend
- make the verification repeatable with concrete commands

## Commands

Generate SDK docs in `jaspr` format:

```bash
tmpdir=$(mktemp -d /tmp/dart-sdk-jaspr.XXXXXX) && \
dart run /Users/belief/dev/projects/dartdoc-vitepress/bin/dartdoc_vitepress.dart \
  --sdk-docs \
  --format jaspr \
  --output "$tmpdir"
```

Benchmark the generated search index:

```bash
dart run tool/jaspr_search_benchmark.dart \
  "$tmpdir/web/generated/search_index.json" \
  Future Stream Uri File
```

Run the generated-scaffold smoke checker:

```bash
dart run /Users/belief/dev/projects/dartdoc-vitepress/tool/jaspr_scaffold_smoke.dart \
  "$tmpdir"
```

Benchmark normalization now mirrors the browser runtime:
- Unicode letters and digits are preserved via `\p{L}` / `\p{N}`
- regression coverage includes a non-Latin query fixture (`Пример`)

## Latest Verification

Date:
- 2026-03-31

Source:
- local Flutter/Dart SDK from `/Users/belief/dev/flutter/bin/cache/dart-sdk`
- large real project: `/Users/belief/dev/projects/headless/packages/headless`

Generation result:
- generation completed successfully
- output: `/tmp/headless-jaspr-docs-9`
- total generation time: `99.2s`
- result: `206 public libraries`, `5701 written`, `22 warnings`, `0 errors`

Search index metrics:
- total entries: `144464`
- manifest: `226` bytes
- page chunk: `1928674` bytes, `5693` entries
- section metadata chunk: `5434458` bytes, `138771` entries
- section content chunk: `23909711` bytes, `138771` entries
- total output size: `173 MB`
- compared to previous iterations on the same project:
  - monolithic search JSON: `63 MB`
  - split search with duplicated section metadata: `1.8 MB + 44 MB`
  - split search with referenced section metadata: `1.8 MB + 25 MB`
  - current two-step search: `1.8 MB + 5.2 MB + 23 MB`

Sample relevance checks:

`Future`
- page chunk top result: `/api/dart-async/Future`
- manifest benchmark top result: `/api/dart-async/Future`

`Stream`
- page chunk top result: `/api/dart-async/Stream`
- manifest benchmark top result: `/api/dart-async/Stream`

`Uri`
- page chunk top result: `/api/dart-core/Uri`
- manifest benchmark top result: `/api/dart-core/Uri`

`File`
- page chunk top result: `/api/dart-io/File`
- manifest benchmark top result: `/api/dart-io/File`

`State`
- manifest benchmark top result: `/api/widgets/State`

`Theme`
- manifest benchmark top result: `/api/material/Theme`

`BuildContext`
- manifest benchmark top result: `/api/widgets/BuildContext`

`Context`
- manifest benchmark top result: `/api/widgets/BuildContext`

Observed benchmark timings:
- page chunk parse: `8915ms`
- page chunk query timings:
  - `Future`: `11.599ms`
  - `Stream`: `5.676ms`
  - `Uri`: `4.887ms`
  - `File`: `5.640ms`
- manifest benchmark parse: `54685ms`
- manifest benchmark query timings:
  - `Future`: `137.298ms`
  - `Stream`: `139.596ms`
  - `Uri`: `120.706ms`
  - `File`: `112.886ms`

Important note:
- the manifest benchmark eagerly loads both chunks and is intentionally a worst-case offline measurement
- browser runtime does not pay this cost on first open because it fetches the page chunk first and only loads section entries when deeper search is needed

## Assessment

Relevance:
- `9/10`
- exact page-level entries rank first for tested canonical queries on both page-only and full manifest benchmarks

Performance:
- `9.0/10`
- first-load payload is small, and the first deferred section step is now metadata-only
- full section content is loaded only for deeper search when needed

Reliability:
- `9/10`
- generation, scaffold build, and search index creation are all repeatable

Mobile usability:
- `8/10`
- search overlay layout includes mobile-specific responsive styles
- no browser-device manual run was performed in this verification log

## Notes

What was improved to reach this result:
- structural sections like `Methods`, `Properties`, `Operators`, `Classes` are filtered from the index
- inherited `Object` noise such as `hashCode`, `runtimeType`, `toString`, `noSuchMethod` is filtered when it adds no search value
- `searchText` payload is truncated to keep the JSON size under control
- section entries now reference page metadata instead of duplicating `kind`, `title`, and full page URL
- section search now uses two stages:
  - metadata chunk for headings and lightweight matching
  - content chunk for deeper full-text matching
- ranking prefers exact page-level matches over constructor/member overloads for common type queries
- ranking now also favors concise framework-level types over longer suffix matches for short queries like `Context`

Recommended next check if needed:
- run the generated Jaspr site in a browser and confirm perceived responsiveness when metadata-only section search upgrades to full section content
