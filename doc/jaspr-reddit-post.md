# Jaspr Reddit Draft

Status:
- ready to adapt for a real post

## Best Title Options

- I built a Jaspr backend for dartdoc so Dart and Flutter packages can ship a Dart-native docs site
- `dartdoc` now outputs Jaspr docs sites too, not just HTML or VitePress
- A Dart-native docs app backend for `dartdoc`: search, theming, breadcrumbs, DartPad, Mermaid

## Short Version

I’ve been working on a fork of `dartdoc` that now supports three outputs:
- `html`
- `vitepress`
- `jaspr`

The interesting part for Flutter and Dart teams is the Jaspr backend.

The goal was not “dump markdown somewhere”. The goal was to get close to the strongest docs UX we already had in the VitePress backend while staying much closer to the Dart toolchain.

Current Jaspr capabilities:
- staged local search for API docs and guides
- theme presets plus runtime light and dark toggle
- SPA-style navigation feel
- breadcrumbs plus outline
- inline API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time code imports for guide snippets
- typed Dart sidebar data instead of TS strings

I also verified it on a real Flutter workspace:
- `206` public libraries
- `5701` generated files
- `0` errors

My honest framing is not “replace VitePress for everyone”.

It is:
- `vitepress` = ecosystem-first backend
- `jaspr` = Dart-first backend

If your team wants docs customization to stay closer to Dart instead of moving into a Vue or TypeScript stack, that is where the Jaspr backend becomes compelling.

What I’d love feedback on:
- does the Dart-native angle feel compelling enough?
- what docs UX gaps would still block you from trying it?
- if you maintain a package, would you prefer VitePress or Jaspr as the target scaffold?

## Reddit-Sized Version

I’ve been working on a fork of `dartdoc` that now supports `html`, `vitepress`, and `jaspr`.

The Jaspr backend was the interesting part for me. I didn’t want a plain markdown export, I wanted a Dart-native docs site that still had the good UX we already had in the VitePress version.

Current Jaspr output has:
- staged local search for API docs and guides
- runtime theme toggle
- SPA-style navigation
- breadcrumbs plus outline
- inline API auto-linking
- DartPad embeds
- Mermaid
- typed Dart sidebar data

I also ran it on a real Flutter workspace and it generated:
- `206` public libraries
- `5701` generated files
- `0` errors

I do not think this replaces VitePress for everyone.

My honest framing is:
- `vitepress` = ecosystem-first backend
- `jaspr` = Dart-first backend

If you maintain a Dart or Flutter package, would that be interesting enough to try?

## Longer Version

I’ve been working on a fork of `dartdoc` that now supports multiple outputs:
- `html`
- `vitepress`
- `jaspr`

The Jaspr backend is the part I think Flutter and Dart people may care about.

The goal was not “export markdown and call it a day”. I wanted a Dart-native docs application that still preserved the strongest UX parts we already had in the VitePress backend.

What the Jaspr scaffold supports now:
- staged local search for API docs and guides
- theme presets plus runtime light and dark toggle
- SPA-style navigation feel
- breadcrumbs and right-side outline
- inline API auto-linking
- DartPad embeds
- Mermaid diagrams
- build-time code import expansion for guide snippets
- typed generated sidebar data in Dart

I also verified it on a real Flutter workspace:
- `206` public libraries
- `5701` generated files
- `0` errors

My honest framing is not “Jaspr beats VitePress for everyone”.

It is:
- `vitepress` is the ecosystem-first option
- `jaspr` is the Dart-first option

So if your team wants to keep docs customization closer to the Dart toolchain, this may be much more interesting than sending everything into a Vue or TypeScript stack.

If there is interest, I can share a cleaner hosted demo and a direct `vitepress vs jaspr` comparison.

## Good Closing Questions

- Would you use a Dart-native docs scaffold for package docs?
- What would still block you from trying Jaspr output on a real package?
- If you already use VitePress, what would Jaspr need to do before you would seriously consider it?
