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
| Build speed / file count | Many HTML pages | Much faster, far fewer files | Much faster, far fewer files |
| DartPad embeds | No | Yes | Yes |
| Mermaid diagrams | No | Yes, with zoom | Yes, with runtime rendering |
| Customization | Templates | CSS, Vue components, plugins | Dart components, theme tokens, CSS |

### Why It Builds Much Faster

`dartdoc_modern` is dramatically faster largely because it writes dramatically fewer files.

Standard `dartdoc` creates a separate HTML page for every member. Every method, property, constructor, and constant gets its own full HTML page with head, navigation, sidebar, and footer. `dartdoc_modern` keeps members inline on the library or type page instead.

- The Flutter `Icons` class has about 2,000 static constants. `dartdoc` turns that into about 2,001 pages for one class. `dartdoc_modern` keeps it on one page.
- For the full Dart SDK, `dartdoc` generates roughly 15,000+ HTML files. `dartdoc_modern` generates about 1,800 markdown files, around 52 MB of source markdown.
- For icon packages like `material_design_icons_flutter` with 7,000+ static const icons, `dartdoc` would emit 7,000+ individual pages. `dartdoc_modern` keeps that as one page.

This is a deliberate architectural choice, not a limitation. It reduces file-system churn, cuts I/O, speeds up builds, and makes browsing APIs better: you can `Ctrl+F` through the whole class, jump with the outline, and use search without opening dozens of member pages.

## Generated With

[dartdoc_modern](https://github.com/777genius/dartdoc_modern) can output both VitePress and Jaspr sites from the same documentation source.
