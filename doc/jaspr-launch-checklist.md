# Jaspr Launch Checklist

Status:
- ready to use

Purpose:
- provide a concrete checklist before posting the `jaspr` backend publicly

## Must Have Before Posting

- `dart run tool/task.dart validate jaspr-launch` passes
- `dart run tool/task.dart validate jaspr-release` passes before the real public post or publish attempt
- if Playwright is not installed in `/tmp/pw-run`, set `PLAYWRIGHT_DIR` explicitly
- generated Jaspr demo builds successfully
- browser route smoke passes on the generated static preview
- browser route smoke passes when the generated site is hosted from a subpath
- search works on both guide and API pages
- `State`, `Theme`, `BuildContext`, and `Context` give convincing results
- theme toggle works and persists
- SPA-style navigation feels correct
- one guide page shows Mermaid, DartPad, code import expansion, and callout blocks
- one API page shows breadcrumbs, signatures, and inline links
- README and public-facing docs are up to date

## Strongly Recommended

- one fresh real large-project proof run exists
- comparison story between `vitepress` and `jaspr` is written down
- Reddit or showcase post draft exists before posting day
- one short capture or gif exists for search, navigation, and theme toggle

## Assets To Prepare

- one desktop screenshot of a guide page
- one desktop screenshot of an API page
- one screenshot of search open with useful results
- one short gif or video of:
  - open search
  - navigate to API result
  - toggle theme

## Suggested Public Links

- repository root README
- `doc/jaspr-community-showcase.md`
- `doc/jaspr-public-demo.md`
- `doc/jaspr-search-verification.md`
- `doc/jaspr-theming.md`
- `doc/jaspr-vs-vitepress.md`

## Suggested Post Shape

1. One sentence: what it is.
2. One sentence: why it is different.
3. Small feature list.
4. One real large-project proof point.
5. Ask for concrete feedback instead of generic praise.

## Avoid In The Post

- claiming `1.0` if you are not ready to support it like one
- claiming Jaspr is better than VitePress for everyone
- vague “AI-generated docs” framing
- giant wall-of-text without one clear screenshot or demo link

## Good Default Positioning

Use language like:
- `strong community preview`
- `Dart-native docs backend`
- `looking for feedback from package maintainers`

Avoid language like:
- `final solution`
- `replacement for all existing docs tooling`
- `production-perfect`
