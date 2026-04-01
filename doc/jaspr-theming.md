# Jaspr Theming

The generated Jaspr scaffold now uses a two-layer theming model:

1. `ContentTheme` for base content colors, typography, and fonts
2. `DocsThemeExtension` for docs-shell tokens such as search, surfaces, callouts, and code controls

This keeps page layout styling separate from content theming and matches the way `jaspr_content` is designed to be extended.

## Quick Start

The generated app reads `DOCS_THEME` at compile time in `lib/main.server.dart`.

Supported presets:

- `ocean`
- `graphite`
- `forest`

Example:

```bash
jaspr serve --dart-define DOCS_THEME=graphite
```

The default preset is `ocean`.

For a subpath deployment, pair the theme with a base path:

```bash
jaspr build \
  --dart-define DOCS_THEME=graphite \
  --dart-define DOCS_BASE_PATH=/my-package-docs
```

For local preview of the generated demo site, use:

```bash
THEME=forest ./tool/jaspr_theme_preview.sh
```

The preview script now uses `jaspr build` and serves the generated static site. This is slower than `jaspr serve`, but it matches production output and keeps route previews accurate.

For a screenshot matrix across presets, use:

```bash
./tool/jaspr_theme_snapshot.sh
```

This now captures:

- `desktop / light`
- `desktop / dark`
- `mobile / light`
- `mobile / dark`

It also writes:

- `manifest.json`
- `index.html` snapshot gallery report

For local validation of the generated theme scaffold and scripts, use:

```bash
dart run tool/task.dart validate jaspr-theme
```

For the heavier visual verification pass, use:

```bash
PLAYWRIGHT_DIR=/tmp/pw-run dart run tool/task.dart validate jaspr-theme-visual
```

For a real golden regression check against the committed baseline, use:

```bash
PLAYWRIGHT_DIR=/tmp/pw-run dart run tool/task.dart validate jaspr-theme-golden
```

To refresh the baseline after an intentional visual redesign, use:

```bash
PLAYWRIGHT_DIR=/tmp/pw-run ./tool/jaspr_theme_golden.sh update
```

Optional env vars:

- `THEME=ocean|graphite|forest`
- `BASE_PATH=/my-package-docs`
- `PORT=4312`
- `OUTPUT_DIR=/tmp/dartdoc-jaspr-preview`
- `PUB_CACHE_DIR=/tmp/dartdoc-pub-cache`
- `PLAYWRIGHT_DIR=/tmp/pw-run` for the screenshot script

Preview note:

- Static preview is served from the built `build/jaspr` output
- `jaspr build` still needs the internal app server on `8080` while generating routes
- `tool/jaspr_theme_preview.sh` safely stops stale preview processes created in `/tmp/dartdoc-jaspr-preview*`
- If some other app is listening on `8080`, the script fails fast and prints the blocking PID/command instead of pretending a different server port will work

## Presets

Presets are defined in `lib/theme/docs_theme.dart`:

- `DocsThemeConfig.ocean()`
- `DocsThemeConfig.graphite()`
- `DocsThemeConfig.forest()`

Each preset controls:

- base `primary`, `background`, and `text`
- content-specific tokens like links, code, and table borders
- font and typography tone
- shell-specific tokens through `DocsThemeExtension`

## Custom Branding

For brand-specific tuning, start from a preset and override the pieces you need:

```dart
final customTheme = DocsThemeConfig.preset(DocsThemePreset.graphite).copyWith(
  primary: ThemeColor(ThemeColors.orange.$600, dark: ThemeColors.orange.$300),
  docs: DocsThemeExtension().copyWith(
    shellAccent: ThemeColor(
      ThemeColors.orange.$600,
      dark: ThemeColors.orange.$300,
    ),
    shellAccentStrong: ThemeColor(
      ThemeColors.orange.$700,
      dark: ThemeColors.orange.$400,
    ),
  ),
);

theme: buildDocsTheme(config: customTheme);
```

You can also swap the overall type tone:

```dart
final editorial = DocsThemeConfig.preset(DocsThemePreset.forest).copyWith(
  font: FontFamily.list([
    FontFamily('Source Serif 4'),
    FontFamilies.uiSerif,
    FontFamilies.serif,
  ]),
);
```

## Best-Practice Notes

- Prefer changing a preset or `DocsThemeConfig` over editing layout selectors
- Keep layout structure in `ApiDocsLayout` and token ownership in `docs_theme.dart`
- Use `DocsThemeExtension` for shell-only values and `ContentTheme`/`ContentColors` for markdown content
- Treat presets as design-time choices; light/dark remains a runtime user preference via `ThemeToggle`
- Give presets different typography and font tone, not only different accent colors
