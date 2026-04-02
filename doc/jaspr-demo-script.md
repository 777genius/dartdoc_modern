---
internal: true
---

# Jaspr Demo Script

Status:
- ready for a short public walkthrough

Purpose:
- give a clean 2-minute demo flow for the `jaspr` backend

## 30-Second Version

1. Open the guide landing page.
2. Hit `Ctrl/Cmd+K`.
3. Search `BuildContext`.
4. Open the API result.
5. Toggle theme.
6. Point out breadcrumbs, outline, inline links, and typed Dart scaffold.

## 2-Minute Version

### 1. Start On A Guide Page

Say:
- “This is the Jaspr backend output, not a static HTML dump.”
- “The docs app itself is Dart-native and generated from the same `dartdoc` model.”

Show:
- the guide layout
- sidebar
- right-side outline
- theme toggle

### 2. Open Search

Hit:
- `Ctrl/Cmd+K`

Search:
- `State`
- `Theme`
- `BuildContext`

Say:
- “Search covers both API pages and guides.”
- “It loads in stages so large doc sets don’t pay the full cost on first open.”

### 3. Open An API Result

Open:
- `BuildContext`

Say:
- “API pages keep breadcrumbs, signatures, inline links, and structured navigation.”

Point to:
- breadcrumbs
- member signatures
- inline linked types
- clean search ranking

### 4. Show Rich Guide Content

Go back to:
- `Getting Started`

Point to:
- Mermaid
- DartPad
- imported code snippet
- callout blocks

Say:
- “This isn’t just API markdown. The guide experience is part of the generated app.”

### 5. Explain Positioning Honestly

Say:
- “I don’t think this replaces VitePress for everyone.”
- “I think `vitepress` is the ecosystem-first backend, and `jaspr` is the Dart-first backend.”

### 6. End With Proof

Say:
- “I also ran it on a real large Flutter workspace: `206` public libraries, `5701` pages, `0` errors.”

## Good Final Line

- “If your team wants docs customization to stay closer to Dart instead of moving into Vue/TypeScript, that’s the real reason this backend exists.”
