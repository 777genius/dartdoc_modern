---
internal: true
---

# Jaspr vs VitePress

Status:
- public-facing comparison

Purpose:
- explain when each backend is the better choice
- avoid pitching `jaspr` as a forced replacement for `vitepress`

## Short Version

Both backends are good.

They optimize for different teams.

- Choose `vitepress` when you want the strongest static-site ecosystem, Vue-level extension power, and a workflow already familiar to docs/front-end engineers.
- Choose `jaspr` when you want a Dart-native docs application, typed generated sidebar data, and a scaffold that your Dart/Flutter team can extend without leaving the Dart ecosystem.

## What They Share

Both outputs now give you:
- generated API documentation from the same `dartdoc` model layer
- guide discovery from `doc/` and `docs/`
- local search
- breadcrumbs and navigation structure
- Mermaid support
- DartPad embeds
- API auto-linking
- a scaffold that can be customized after generation

## Where VitePress Is Still Stronger

- bigger static-site ecosystem
- mature Vue plugin story
- easier fit for teams already comfortable with Node + VitePress
- easier path if you want to lean on existing VitePress community recipes

## Where Jaspr Is Stronger

- Dart-first customization story
- typed sidebar generation in Dart
- easier mental model for Flutter/Dart teams that do not want TypeScript/Vue in their docs stack
- theming via `jaspr_content` + `ContentTheme`
- runtime theme switching and shell customization without leaving Dart

## Decision Guide

If your team says:

- “We already know VitePress, Vue, and markdown-it plugins”
  Then choose `vitepress`.

- “We want our docs site to stay inside the Dart toolchain as much as possible”
  Then choose `jaspr`.

- “We need a polished docs site today and want the lowest-risk path”
  Then choose `vitepress`.

- “We want a serious Dart-native docs app and we are comfortable being early adopters”
  Then choose `jaspr`.

## Honest Positioning

The goal is not to pretend `jaspr` replaces `vitepress` for every team.

The real story is stronger than that:

- `vitepress` is the ecosystem-first backend
- `jaspr` is the Dart-first backend

That is a healthier message for the community because it matches how people actually choose tools.

## Current Recommendation

For public community demos:
- show both
- frame them as two strong outputs from one generator
- then explain why `jaspr` is interesting: it brings the docs experience closer to the Flutter/Dart world instead of sending teams into a separate front-end stack
