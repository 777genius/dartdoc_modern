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

- [x] Actual upstream commit is merged into the draft branch (Git ancestry).
- [x] Every merge conflict is resolved without losing fork functionality.
- [x] No unexplained analyzer, format, build, or test failures.
- [x] HTML/Jaspr/VitePress generation + documented E2E pass.
- [x] Browser/visual checks or precise limitation recorded.
- [x] Review/fix cycle complete; all blockers addressed.
- [x] Draft PR records upstream SHA, conflict decisions, exact test links,
      exceptions, and remaining risks.

## Verified integration evidence (2026-11-06)

- The actual non-squashed three-way merge is `1b39d37312190e234ab3f8a3be4b42f4e18c938d`;
  its second parent is `dart-lang/dartdoc@03ec6df6228ac8257a737261d17e746c665b1e13`.
  [Pinned upstream compare](https://github.com/777genius/dartdoc_modern/compare/03ec6df6228ac8257a737261d17e746c665b1e13...008c636399da25ce9c5ca7b77b744cafbf7b9e06):
  `behind_by=0`, `ahead_by=290`.
- Existing fork-specific HTML/Jaspr/VitePress generators, CLI package identity,
  search/routes/theme features and source-generated JS/CSS/AOT resource handling
  remain covered by regression tests. Merge conflicts were resolved as documented
  in the PR; necessary focused follow-up changes were limited to compatibility,
  canonical links, test resources and platform-specific behavior.
- [Full cross-platform E2E #42169075922](https://github.com/777genius/dartdoc_modern/actions/runs/42169075922):
  **success** for Ubuntu, macOS and Windows. The verification matrix checked out
  the exact merged SHA `008c636399da25ce9c5ca7b77b744cafbf7b9e06` and ran
  `dart pub get`, Dart buildbot (analyzer with fatal infos, formatting,
  tests and build), release-level package validation, HTML/Jaspr/VitePress E2E.
- On Linux, Playwright browser/search/routes/themes and Jaspr visual checks all
  passed. The twelve reviewed Jaspr theme pixel baselines were refreshed in
  `008c636`, and **strict golden verification passed** (not skipped).
  `dart run tool/task.dart validate package-release` passed, including the
  VitePress smoke suite (188 tests).
- Linux standalone AOT was compiled and executed **outside the repository**:
  HTML generation with bundled assets; external CSS override; Jaspr and
  VitePress generation. All completed successfully.
- [Publish validation dry-run #42169081495](https://github.com/777genius/dartdoc_modern/actions/runs/42169081495)
  succeeded. This validation is `dart pub publish --dry-run` only; no package
  was released or tagged. The later `action_required` status on the
  token-generated golden commit reflects missing pull_request dispatch for
  GITHUB_TOKEN pushes, not a failed validation gate.
- All eleven original CodeRabbit review threads are resolved. The questioned
  `PrimaryConstructorBody` handling matches pinned upstream and is covered
  by upstream primary constructor tests; the resource-loading review concern
  was verified by standalone AOT and CSS override E2E.
- After that complete green E2E, remove the one-off sync workflow and conflict
  resolution script to avoid shipping temporary CI infrastructure.

## Finalization checklist

- [x] Finish source-level integration, 3-platform E2E, browser, visual,
      strict pixel goldens, and standalone AOT before cleanup.
- [x] Review/fix all original eleven review threads.
- [x] Remove temporary `.github/workflows/upstream-sync-once.yml`
      and `tool/upstream-sync-resolutions.sh` in the cleanup commit.
- [ ] Obtain final existing PR CI validation/dry-run and review on the cleanup
      commit (without publishing).
- [ ] Mark PR Ready and merge using GitHub `merge` only, **never squash/rebase**.
- [ ] Reconfirm pinned upstream is in `main` ancestry and inspect post-merge
      `main` CI before concluding.

Keep PR as Draft until the final CI check and review have been checked.
