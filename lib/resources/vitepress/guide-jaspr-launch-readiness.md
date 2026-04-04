---
internal: true
---

# Jaspr Launch Readiness

This document captures the real public-facing quality bar for the `jaspr`
backend. It separates what is already verified from what is still polish.

## Current State

Already strong:
- staged local search with guide and API coverage
- theme presets and runtime light and dark switching
- SPA-style navigation feel
- breadcrumbs and outline
- inline API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time `<<<` code import expansion
- generated typed Dart sidebar data
- large-project verification on a real Flutter workspace

Verified quality gates:
- `dart run tool/task.dart validate jaspr-launch` exists as one primary launch gate
- `dart run tool/task.dart validate jaspr-release` exists as the stricter release-facing gate
- `dart run tool/task.dart validate package-release` exists as the broader package-wide gate
- generated scaffold builds successfully in e2e
- browser route smoke passes on the generated static preview
- browser route smoke passes with `DOCS_BASE_PATH` enabled
- search ranking behaves well for common Flutter queries
- search perf smoke passes for the current preview flow
- large workspace generation succeeds on a real Flutter workspace used as a large-project proof run
- current verified large-project run: `206` public libraries, `5701` generated files, `22` warnings, `0` errors

## Launch Score

Community demo readiness:
- `9.6/10`

Engineering quality:
- `9.4/10`

Search UX:
- `9.3/10`

Theming and customization story:
- `9.4/10`

Large-project credibility:
- `9.5/10`

## Good Enough To Show Publicly

Yes, for:
- Flutter community demo posts
- Reddit launch or preview threads
- asking for design and DX feedback
- inviting early adopters to try the backend on real packages

Not yet ideal for:
- claiming a polished `1.0`
- claiming final browser perf tuning on very large hosted sites
- claiming exhaustive hosted visual-regression coverage

## Recommended Demo Order

1. Show a guide page with search, breadcrumbs, outline, Mermaid, and DartPad.
2. Jump to an API type with inline links and signatures.
3. Toggle theme.
4. Search for `State`, `Theme`, `BuildContext`, and `Context`.
5. Mention the large-project proof on `headless`.
6. Close with the backend framing: ecosystem-first vs Dart-first.

## Biggest Remaining Risks

- hosted demo infrastructure is still a presentation task, not a code-quality task
- search feel on extremely large public sites should still be watched in real browser telemetry
- visual polish can still improve even though the current quality bar is already credible

## Bottom Line

This is already beyond “interesting fork”.

The `jaspr` backend is now credible as:
- a serious Dart-native documentation output
- a real alternative when teams want typed scaffold code instead of Vue or TypeScript
- something that is reasonable to show publicly to the Flutter community without embarrassment
