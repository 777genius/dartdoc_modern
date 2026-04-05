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
      text: Get Started
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

This site is generated from your package source and keeps guides plus API pages in one Jaspr app.

<Tabs defaultValue="guide">
  <TabItem label="Guide" value="guide">

Guide pages work best for onboarding, architecture notes, or explaining how the public API fits together.

  </TabItem>
  <TabItem label="API" value="api">

API pages keep every library, type, member, signature, and inherited detail searchable and deep-linkable.

  </TabItem>
</Tabs>

## Generated With

[dartdoc_modern](https://github.com/777genius/dartdoc_modern) can output both VitePress and Jaspr sites from the same documentation source.
