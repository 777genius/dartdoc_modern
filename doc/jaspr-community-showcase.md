---
internal: true
---

# Jaspr Community Showcase

This is the clean public-facing page to link when showing the `jaspr` backend
to the Dart and Flutter community. It is meant to stay honest, specific, and
evidence-based.

## One-Sentence Pitch

`dartdoc_modern` adds a Jaspr backend to `dartdoc`, so Dart and Flutter packages can ship a Dart-native docs site with search, guides, theming, breadcrumbs, Mermaid, DartPad, and typed generated scaffold data instead of plain generated HTML.

## Why Flutter And Dart People Should Care

Most Dart and Flutter teams do not want to maintain their package docs in a separate Vue or TypeScript stack unless there is a strong reason.

That is the real opening for `jaspr`.

The interesting part is not “another markdown export”.

The interesting part is:
- analyzer-driven API docs from `dartdoc`
- guide support next to API docs
- a real docs application scaffold
- theming and extension points that stay much closer to the Dart toolchain

## What It Actually Gives You

The Jaspr backend currently gives you:
- staged local search for API docs and guides
- theme presets with persisted light and dark switching
- SPA-style navigation feel
- breadcrumbs and right-side outline
- inline API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time code import expansion for guide snippets
- typed Dart sidebar generation

## Honest Positioning

Do not frame this as “Jaspr replaces VitePress for everyone”.

The truthful and stronger framing is:
- `vitepress` is the ecosystem-first backend
- `jaspr` is the Dart-first backend

That is what makes the project credible.

## Proof That It Is Not Just A Toy

Large-project verification was done on:
- a real Flutter workspace used as a large-project proof run

Verified run:
- `206` public libraries
- `5701` generated files
- `0` errors

Public-quality launch gate:

```bash
dart run ./tool/task.dart validate jaspr-launch
```

That gate covers:
- generated scaffold buildability
- preview and theme flow
- browser route smoke
- search performance smoke

## Best 90-Second Demo

1. Open `Getting Started` and show search, breadcrumbs, outline, Mermaid, and DartPad.
2. Search for `Greeter` and jump into an API page.
3. Toggle theme.
4. Mention that the same generator also supports `vitepress` and `html`.
5. Close with the real framing: ecosystem-first vs Dart-first.

## What To Avoid Saying

Avoid:
- “This replaces VitePress.”
- “This is 1.0.”
- “This is done.”
- “This is just a theme layer.”

Prefer:
- “strong community preview”
- “serious Dart-native docs backend”
- “looking for feedback from package maintainers”

## Best Links To Share

- [Project Overview](../)
- [Jaspr Public Demo Checklist](jaspr-public-demo.md)
- [Jaspr Deployment](jaspr-deployment.md)
- [Jaspr Search Verification](jaspr-search-verification.md)
- [Jaspr Theming](jaspr-theming.md)
- [Jaspr vs VitePress](jaspr-vs-vitepress.md)
- [Jaspr Launch Checklist](jaspr-launch-checklist.md)
- [Jaspr Launch Readiness](jaspr-launch-readiness.md)
- [Jaspr Reddit Draft](jaspr-reddit-post.md)
- [Jaspr Demo Script](jaspr-demo-script.md)
- [Jaspr Post Assets](jaspr-post-assets.md)
