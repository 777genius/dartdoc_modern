# Jaspr Community Showcase

Status:
- ready to share

Purpose:
- provide one clean page to link when showing the `jaspr` backend publicly

## What This Is

`dartdoc-vitepress` now has three outputs:
- `html`
- `vitepress`
- `jaspr`

The `jaspr` backend is the Dart-first option.

It generates a real Jaspr docs application, not just a markdown dump.

## Why It Is Interesting

- Dart-native docs scaffold
- typed generated sidebar data
- staged local search for API docs and guides
- runtime light/dark theme switching
- SPA-style navigation feel
- breadcrumbs and outline
- inline API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time code import expansion for guide snippets

## Real Proof

Large-project verification was done on:
- `/Users/belief/dev/projects/headless/packages/headless`

Result:
- `206` public libraries
- `5701` generated pages
- `0` errors

Search quality checks now rank expected Flutter types well:
- `State` -> `/api/widgets/State`
- `Theme` -> `/api/material/Theme`
- `BuildContext` -> `/api/widgets/BuildContext`
- `Context` -> `/api/widgets/BuildContext`

## Honest Framing

This is not “Jaspr replaces VitePress for everyone”.

The better framing is:
- `vitepress` is the ecosystem-first backend
- `jaspr` is the Dart-first backend

That is the real reason this is interesting to the Flutter community.

## Best Links To Share

- [README](/Users/belief/dev/projects/dartdoc-vitepress/README.md)
- [Jaspr vs VitePress](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-vs-vitepress.md)
- [Jaspr Search Verification](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-search-verification.md)
- [Jaspr Public Demo Checklist](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-public-demo.md)
- [Jaspr Launch Readiness](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-launch-readiness.md)
- [Jaspr Reddit Draft](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-reddit-post.md)
- [Jaspr Demo Script](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-demo-script.md)
- [Jaspr Post Assets](/Users/belief/dev/projects/dartdoc-vitepress/doc/jaspr-post-assets.md)

## Suggested One-Sentence Pitch

“I added a Jaspr backend to `dartdoc` so Dart and Flutter packages can ship a Dart-native docs site with real search, theming, guides, and interactive docs features instead of plain generated HTML.”
