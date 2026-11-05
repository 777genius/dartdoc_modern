# Upstream sync plan — 2026-11-05

## Goal and fixed baseline

Integrate `dart-lang/dartdoc@03ec6df6228ac8257a737261d17e746c665b1e13` into
`777genius/dartdoc_modern@d2715fb963ef1b3dfffbf41a0892db9adb807a64`
on a dedicated draft PR. The two branches diverged at
`a57f497ae9df6e6073b5eb7ddf253d0b2eb470c3` (260 upstream commits,
58 fork commits as of planning).

Do **not** sync directly into `main`. Preserve independent features while
adopting upstream bug fixes and maintenance changes.

## In scope

1. Inspect upstream and fork changes, existing workflow gates, and overlapping
   files before making merge decisions.
2. Perform an actual Git three-way merge of the pinned upstream commit into
   this branch; preserve ancestry. Resolve only real conflicts, with an explicit
   file-by-file rationale where semantics differ.
3. Preserve `dartdoc_modern` package/executables, the fork's CLI options,
   HTML, Jaspr, VitePress, workspace/guide output, generated scaffolds,
   browser navigation, theme, and search. Do not lose upstream bug fixes.
4. Repair only compatibility issues revealed by this merge (not opportunistic
   refactors), including analyzer/API version compatibility and generated
   resources where needed.
5. Verify `dart pub get`, `dart analyze --fatal-infos`, formatting/buildbot,
   relevant tests, `dart run tool/task.dart validate package-release`
   (or its individual documented gates). Require Linux plus supported
   Windows/macOS test coverage where CI offers it.
6. Build HTML, Jaspr, and VitePress documentation from a representative package;
   check links, navigation, search, theming, and subpath deployment with
   browser E2E and visual inspection/screenshots when accessible.
7. Review merged code for silent feature loss and upstream contract drift,
   apply focused fixes, rerun failed gates, and document evidence in this PR.

## Merge policy / risk controls

- **Package metadata**: retain `dartdoc_modern` identity, published version
  and executable aliases; integrate compatible upstream dependencies carefully.
- **Core Dart model/generator**: prefer upstream correctness fixes, preserving
  compatibility for both custom backends and HTML. No blanket “ours/theirs”
  resolution for core logic.
- **Generated HTML/JS**: rebuild via the repository's existing generation tasks
  rather than hand-editing minified/generated output.
- **CI and publishing**: retain fork-specific coverage and publishing semantics;
  never publish to pub.dev or deploy Pages from this sync branch.
- **Docs-site**: preserve working Jaspr/VitePress scaffolds, verify rendering;
  don't change unrelated design/content.

## Explicitly out of scope

New features, general architecture refactors, dependency updates not required
by upstream, unrelated code style sweeps, releases/tags, production deploys,
main-branch changes, and rewriting existing backends.

## Exit criteria

- [ ] Actual upstream commit is merged into the draft branch (Git ancestry).
- [ ] Every merge conflict is resolved without losing fork functionality.
- [ ] No unexplained analyzer, format, build, or test failures.
- [ ] HTML/Jaspr/VitePress generation + documented E2E pass.
- [ ] Browser/visual checks or precise limitation recorded.
- [ ] Review/fix cycle complete; all blockers addressed.
- [ ] Draft PR records upstream SHA, conflict decisions, exact test links,
      exceptions, and remaining risks.

If the integration is not verified, keep the PR draft and never claim success.
