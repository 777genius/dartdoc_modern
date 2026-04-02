---
internal: true
---

# Release Playbook

Status:
- maintainer-facing
- release-ready

Purpose:
- give one short path from local changes to a credible public release
- avoid relying on tribal knowledge or a remembered sequence of commands

## 1. Run The Strongest Gate

From the repository root:

```bash
dart run ./tool/task.dart validate package-release
```

This covers:
- repo-wide `dart analyze --fatal-infos`
- `dart pub publish --dry-run`
- full `jaspr-release`
- full `vitepress` end-to-end smoke suite

If Playwright is installed outside `/tmp/pw-run`, set `PLAYWRIGHT_DIR` first.

## 2. Check The Remaining Dry-Run Warning

`dart pub publish --dry-run` is expected to warn when the git worktree is dirty.

Before a real release:
- review `git status`
- make sure the diff is intentional
- make sure there are no accidental temp artifacts or local-only edits

## 3. Sanity-Check The Public Story

Before posting or publishing, re-read:
- [Project Overview](../)
- [Package Maintainer Recipes](package-maintainer-recipes.md)
- [Jaspr Community Showcase](jaspr-community-showcase.md)
- [Jaspr Launch Readiness](jaspr-launch-readiness.md)

The goal is simple:
- package consumers should understand how to use the tool
- community readers should understand why `jaspr` exists
- the project should not read like an internal notebook

## 4. Publish

When the worktree is clean and the gate is green:

```bash
dart pub publish
```

## 5. Post-Release Public Message

Use the honest framing:
- `vitepress` = ecosystem-first backend
- `jaspr` = Dart-first backend

Avoid:
- claiming `1.0` unless the project is truly ready for that bar
- claiming `jaspr` replaces `vitepress` for every team
- overselling performance on every possible large hosted site

Prefer:
- `strong community preview`
- `serious Dart-native docs backend`
- `looking for feedback from package maintainers`

## 6. If You Need A Faster Final Check

Use:

```bash
dart run ./tool/task.dart validate jaspr-release
```

That is the stricter public-facing Jaspr gate without the full VitePress suite.

## Related Docs

- [Project Overview](../)
- [Package Maintainer Recipes](package-maintainer-recipes.md)
- [Jaspr Launch Checklist](jaspr-launch-checklist.md)
- [Jaspr Launch Readiness](jaspr-launch-readiness.md)
- [Jaspr Deployment](jaspr-deployment.md)
