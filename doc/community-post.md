---
internal: true
---

# dartdoc_modern - community post draft

Hey Flutter devs!

I made an alternative docs generator for Dart that produces clean, modern-looking doc sites using [Jaspr](https://jaspr.site/) - a Dart web framework - instead of the default dartdoc HTML. If you maintain a Flutter or Dart package, you can generate beautiful documentation for it in literally 3 commands. Since Flutter packages are Dart packages, it works with them out of the box.

Here's a live demo - the entire **Dart SDK API** generated with it: [**https://777genius.github.io/dart-sdk-api/**](https://777genius.github.io/dart-sdk-api/)

# What you get out of the box

- **Fully Dart-native** - the entire docs site is a Jaspr app, no JS/Node tooling required
- **Fully customizable** - theme, extra pages, your own Dart components
- **Full-text search** across all libraries (Ctrl+K / Cmd+K) - no external service, works offline
- **Interactive DartPad** - run code examples right in the docs ([try it here](https://777genius.github.io/dart-sdk-api/guide/#try-it-now))
- **Linked type signatures** - every type in a method signature is clickable
- **Auto-linked references** - `List` or `Future` in doc comments become links automatically
- **Guide pages** - write markdown in `doc/` and it becomes part of your docs site
- **Collapsible outline** for large API pages with dozens of members
- **Copy button** on all code blocks
- **Mobile-friendly** - actually usable on a phone
- **Dark mode** that actually looks good
- **Mermaid diagrams** with lightbox zoom
- **Good SEO** thanks to Jaspr SSR pre-rendering

# How to use it

```bash
dart pub global activate dartdoc_modern
dartdoc_modern --output docs-site
cd docs-site && dart pub get && jaspr serve
```

Your existing `///` doc comments are all it needs. Works with single packages and mono-repos (Dart workspaces with `--workspace-docs`). The output is a standard static site - deploy to GitHub Pages, Firebase Hosting, Vercel, or anywhere else.

For production builds:

```bash
cd docs-site && jaspr build
```

# VitePress alternative

If you prefer the JS/Vue ecosystem, there's also a `--format vitepress` output:

```bash
dartdoc_modern --format vitepress --output docs-site
cd docs-site && npm install && npx vitepress dev
```

VitePress gives you the richest static-site plugin ecosystem (Vue components, community themes, etc.) and is a solid choice if your team already works with JS tooling. Both formats generate from the same doc comments and support the same features.

# Why I built this

The default dartdoc output works but feels dated and is hard to customize. I wanted docs that look like what you see from modern JS/TS libraries - searchable, dark mode, nice typography - but generated from Dart doc comments without changing how you write them.

The Jaspr backend means your entire docs pipeline stays in Dart. No Node.js, no npm, no Vue - just `dart pub get` and `jaspr build`. Your Flutter/Dart team can extend the docs site with Dart components they already know how to write.

It's a fork of dartdoc with alternative `--format` flags. The original HTML output still works if you need it (`--format html`), nothing breaks.

# Links

- **Live demo (Dart SDK):** [https://777genius.github.io/dart-sdk-api/](https://777genius.github.io/dart-sdk-api/)
- **pub.dev:** [https://pub.dev/packages/dartdoc_modern](https://pub.dev/packages/dartdoc_modern)
- **GitHub:** [https://github.com/777genius/dartdoc_modern](https://github.com/777genius/dartdoc_modern)

Happy to answer any questions! Feedback and feature requests welcome.
