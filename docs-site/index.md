---
layout: home
hero:
  name: "dartdoc_modern"
  text: Modern API Docs for Dart
  tagline: Drop-in replacement for dart doc — generates a VitePress site with search, dark mode, and full customization
  actions:
    - theme: brand
      text: Quick Start
      link: /guide/
    - theme: alt
      text: API Reference
      link: /api/
    - theme: alt
      text: Jaspr Version
      link: https://777genius.github.io/dartdoc_modern/jaspr/
    - theme: alt
      text: VitePress Version
      link: https://777genius.github.io/dartdoc_modern/vitepress/
    - theme: alt
      text: GitHub
      link: https://github.com/777genius/dartdoc_modern
features:
  - icon: 📚
    title: Full API Reference
    details: Every class, function, and type gets its own page with clickable type links and syntax-highlighted signatures.
  - icon: 🔍
    title: Fast Offline Search
    details: Built-in full-text search across all pages. Works offline, no external service required.
  - icon: 🌙
    title: Dark Mode & Theming
    details: Light/dark toggle out of the box. Customize with CSS or build Vue components — full VitePress ecosystem.
  - icon: 📖
    title: Guide Pages
    details: Put markdown files in doc/ or docs/ — they become guide pages with auto-generated sidebar navigation.
  - icon: 📦
    title: Mono-repo Support
    details: One command generates unified docs for all packages in a Dart workspace with --workspace-docs.
  - icon: 🎮
    title: Interactive DartPad
    details: Tag a code block with dartpad and it becomes a live, editable Dart playground inside your docs.
  - icon: 🔗
    title: Auto-Linking
    details: Write `ClassName` in your guides and it automatically links to the API page. No manual URLs.
  - icon: ⚡
    title: Incremental Generation
    details: Only rewrites changed pages. Re-runs are fast even for large packages.
---

## Install

```bash
dart pub global activate dartdoc_modern
```

## Usage

::: code-group
```bash [Single package]
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```
```bash [Mono-repo]
dartdoc_modern --format vitepress \
  --workspace-docs \
  --exclude-packages 'example,test_utils' \
  --output docs-site
```
```bash [Dart SDK]
dartdoc_modern --sdk-docs --format vitepress --output docs-site
```
:::

## dart doc vs dartdoc_modern

| | dart doc | dartdoc_modern |
|---|---|---|
| Output | Static HTML | VitePress (Markdown + Vue) |
| Search | Basic | Full-text, offline |
| Dark mode | No | Yes |
| Guide docs | No | Auto from doc/ |
| Mono-repo | No | --workspace-docs |
| DartPad embeds | No | Yes |
| Mermaid diagrams | No | Yes, with zoom |
| Customization | Templates | CSS, Vue components, plugins |

## Live Example

[Dart SDK API docs](https://777genius.github.io/dart-sdk-api/) — 56 libraries, 1800+ pages, generated with dartdoc_modern.

## Live Versions

- [VitePress version](https://777genius.github.io/dartdoc_modern/vitepress/)
- [Jaspr version](https://777genius.github.io/dartdoc_modern/jaspr/)
