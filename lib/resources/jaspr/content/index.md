---
layout: home
title: "{{packageName}}"
description: "API documentation for {{packageName}}"
hero:
  name: "{{packageName}}"
  text: API Documentation
  tagline: Generated with dartdoc_modern
  actions:
    - theme: brand
      text: Quick Start
      link: /guide/
    - theme: alt
      text: API Reference
      link: /api/
features:
  - icon: 🧭
    title: Guided Reading
    details: Use guide pages for overviews, recipes, migration notes, and architecture context next to the generated API docs.
  - icon: 🔎
    title: Fast Search
    details: Search across guides, API pages, and section headings without depending on an external indexing service.
  - icon: 🧩
    title: Typed Navigation
    details: Jaspr keeps the generated sidebar, routes, and page metadata inside the docs app instead of a fragile JS config layer.
  - icon: 🎨
    title: Theme Presets
    details: Ship a ready-made docs shell with light and dark mode, polished surfaces, and room for package branding.
---

## Start Here

This site is generated from your package source and keeps guides plus API pages in one Jaspr app. Start with installation, then choose the output that fits your docs stack.

### Install

```bash
dart pub global activate dartdoc_modern
```

### Usage

<Tabs defaultValue="jaspr">
  <TabItem label="Jaspr" value="jaspr">

#### Single package

```bash
dartdoc_modern --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve
```

#### Mono-repo

```bash
dartdoc_modern --format jaspr \
  --workspace-docs \
  --exclude-packages 'example,test_utils' \
  --output docs-site
cd docs-site && dart pub get && jaspr serve
```

#### Dart SDK

```bash
dartdoc_modern --sdk-docs --format jaspr --output docs-site
cd docs-site && dart pub get && jaspr serve
```

  </TabItem>
  <TabItem label="VitePress" value="vitepress">

#### Single package

```bash
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```

#### Mono-repo

```bash
dartdoc_modern --format vitepress \
  --workspace-docs \
  --exclude-packages 'example,test_utils' \
  --output docs-site
```

#### Dart SDK

```bash
dartdoc_modern --sdk-docs --format vitepress --output docs-site
```

  </TabItem>
</Tabs>

### What Goes Where

- Guides are best for onboarding, architecture notes, recipes, and migration docs.
- API pages keep every library, type, member, signature, and inherited detail searchable and deep-linkable.
- VitePress is the richer static docs stack; Jaspr keeps everything inside one Dart-driven docs app.

## Live Versions

- [VitePress version](https://777genius.github.io/dartdoc_modern/vitepress/)
- [Jaspr version](https://777genius.github.io/dartdoc_modern/jaspr/)

## dart doc vs dartdoc_modern

| | dart doc | dartdoc_modern VitePress | dartdoc_modern Jaspr |
|---|---|---|---|
| Output | Static HTML | VitePress (Markdown + Vue) | Jaspr app (Dart + SSR/static build) |
| Search | Basic | Full-text, offline | Full-text, offline |
| Dark mode | No | Yes | Yes |
| Guide docs | No | Auto from `doc/` | Auto from `doc/` |
| Mono-repo | No | `--workspace-docs` | `--workspace-docs` |
| DartPad embeds | No | Yes | Yes |
| Mermaid diagrams | No | Yes, with zoom | Yes, with runtime rendering |
| Customization | Templates | CSS, Vue components, plugins | Dart components, theme tokens, CSS |

## Generated With

[dartdoc_modern](https://github.com/777genius/dartdoc_modern) can output both VitePress and Jaspr sites from the same documentation source.
