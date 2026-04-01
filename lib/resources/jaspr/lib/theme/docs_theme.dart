import 'package:jaspr/dom.dart';
import 'package:jaspr_content/theme.dart';

/// Design presets for the generated docs shell.
///
/// Use a preset when you want to swap the docs personality without editing the
/// layout styles directly. For deeper branding, start from
/// [DocsThemeConfig.preset] and override fields with [copyWith].
enum DocsThemePreset {
  ocean,
  graphite,
  forest,
}

extension DocsThemePresetX on DocsThemePreset {
  String get name => switch (this) {
        DocsThemePreset.ocean => 'ocean',
        DocsThemePreset.graphite => 'graphite',
        DocsThemePreset.forest => 'forest',
      };

  static DocsThemePreset parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'graphite' => DocsThemePreset.graphite,
      'forest' => DocsThemePreset.forest,
      _ => DocsThemePreset.ocean,
    };
  }
}

ContentTheme buildDocsTheme({
  DocsThemeConfig? config,
}) {
  return (config ?? DocsThemeConfig.ocean()).toContentTheme();
}

class DocsThemeConfig {
  DocsThemeConfig({
    required this.primary,
    required this.background,
    required this.text,
    required this.colors,
    required this.typography,
    required this.font,
    required this.codeFont,
    required this.docs,
  });

  factory DocsThemeConfig.ocean() {
    return DocsThemeConfig(
      primary: ThemeColor(ThemeColors.blue.$600, dark: ThemeColors.sky.$300),
      background:
          ThemeColor(const Color('#edf4ff'), dark: ThemeColors.zinc.$950),
      text: ThemeColor(ThemeColors.slate.$800, dark: ThemeColors.zinc.$200),
      colors: _contentColors(
        headings:
            ThemeColor(ThemeColors.slate.$950, dark: Colors.white),
        links: ThemeColor(ThemeColors.blue.$700, dark: ThemeColors.sky.$300),
        lead:
            ThemeColor(ThemeColors.slate.$700, dark: ThemeColors.zinc.$400),
        quotes:
            ThemeColor(ThemeColors.slate.$900, dark: ThemeColors.zinc.$100),
        quoteBorders:
            ThemeColor(const Color('#cfe0ff'), dark: ThemeColors.zinc.$700),
        code:
            ThemeColor(ThemeColors.slate.$950, dark: Colors.white),
        preCode:
            ThemeColor(ThemeColors.slate.$800, dark: ThemeColors.zinc.$200),
        preBg:
            ThemeColor(const Color('#f8fbff'), dark: ThemeColors.zinc.$950),
        thBorders:
            ThemeColor(const Color('#c5d8fb'), dark: ThemeColors.zinc.$700),
        tdBorders:
            ThemeColor(const Color('#d7e4fb'), dark: ThemeColors.zinc.$800),
      ),
      typography: _oceanTypography(),
      font: FontFamily.list([
        const FontFamily('Manrope'),
        FontFamilies.uiSansSerif,
        FontFamilies.systemUi,
        FontFamilies.sansSerif,
      ]),
      codeFont: FontFamily.list([
        const FontFamily('JetBrains Mono'),
        FontFamilies.uiMonospace,
        FontFamilies.monospace,
      ]),
      docs: DocsThemeExtension(
        shellSurface: const ThemeColor(
          Color('rgba(255, 255, 255, 0.82)'),
          dark: Color('rgba(24, 24, 27, 0.92)'),
        ),
        shellSurfaceSoft: const ThemeColor(
          Color('rgba(244, 248, 255, 0.92)'),
          dark: Color('rgba(39, 39, 42, 0.88)'),
        ),
        shellSurfaceElevated: const ThemeColor(
          Color('rgba(255, 255, 255, 0.96)'),
          dark: Color('#18181b'),
        ),
        shellBorder: const ThemeColor(
          Color('rgba(96, 131, 191, 0.18)'),
          dark: Color('rgba(148, 163, 184, 0.18)'),
        ),
        shellBorderStrong: const ThemeColor(
          Color('rgba(96, 131, 191, 0.30)'),
          dark: Color('rgba(148, 163, 184, 0.24)'),
        ),
        shellMuted: const ThemeColor(
          Color('rgba(59, 73, 96, 0.78)'),
          dark: Color('rgba(212, 212, 216, 0.76)'),
        ),
        shellAccent:
            ThemeColor(ThemeColors.blue.$600, dark: ThemeColors.sky.$300),
        shellAccentStrong:
            ThemeColor(ThemeColors.blue.$700, dark: ThemeColors.sky.$400),
        shellAccentSoft: const ThemeColor(
          Color('rgba(37, 99, 235, 0.12)'),
          dark: Color('rgba(125, 211, 252, 0.12)'),
        ),
        shellCalloutBg: const ThemeColor(
          Color('rgba(31, 196, 122, 0.10)'),
          dark: Color('rgba(34, 197, 94, 0.12)'),
        ),
        shellCalloutBorder: const ThemeColor(
          Color('rgba(34, 197, 94, 0.62)'),
          dark: Color('rgba(74, 222, 128, 0.65)'),
        ),
        shellCodeButtonBg: const ThemeColor(
          Color('rgba(255, 255, 255, 0.96)'),
          dark: Color('rgba(39, 39, 42, 0.96)'),
        ),
        shellCodeButtonFg: ThemeColor(
          ThemeColors.slate.$800,
          dark: Colors.white,
        ),
        shellDartPadStage: const ThemeColor(
          Color('rgba(252, 253, 255, 0.98)'),
          dark: Color('#0b1120'),
        ),
        shellShadow: const ThemeColor(
          Color('rgba(52, 84, 140, 0.16)'),
          dark: Color('rgba(2, 6, 23, 0.45)'),
        ),
        shellFocus: const ThemeColor(
          Color('rgba(59, 130, 246, 0.22)'),
          dark: Color('rgba(125, 211, 252, 0.18)'),
        ),
      ),
    );
  }

  factory DocsThemeConfig.graphite() {
    return DocsThemeConfig(
      primary:
          ThemeColor(ThemeColors.indigo.$600, dark: ThemeColors.violet.$300),
      background:
          ThemeColor(ThemeColors.zinc.$50, dark: ThemeColors.zinc.$950),
      text: ThemeColor(ThemeColors.zinc.$700, dark: ThemeColors.zinc.$200),
      colors: _contentColors(
        headings:
            ThemeColor(ThemeColors.zinc.$950, dark: Colors.white),
        links:
            ThemeColor(ThemeColors.indigo.$700, dark: ThemeColors.violet.$300),
        lead:
            ThemeColor(ThemeColors.zinc.$600, dark: ThemeColors.zinc.$400),
        quotes:
            ThemeColor(ThemeColors.zinc.$900, dark: ThemeColors.zinc.$100),
        quoteBorders:
            ThemeColor(ThemeColors.zinc.$300, dark: ThemeColors.zinc.$700),
        code:
            ThemeColor(ThemeColors.zinc.$950, dark: Colors.white),
        preCode:
            ThemeColor(ThemeColors.zinc.$800, dark: ThemeColors.zinc.$200),
        preBg:
            ThemeColor(ThemeColors.zinc.$50, dark: Colors.black),
        thBorders:
            ThemeColor(ThemeColors.zinc.$300, dark: ThemeColors.zinc.$700),
        tdBorders:
            ThemeColor(ThemeColors.zinc.$200, dark: ThemeColors.zinc.$800),
      ),
      typography: _graphiteTypography(),
      font: FontFamily.list([
        const FontFamily('Avenir Next'),
        FontFamilies.uiRounded,
        FontFamilies.systemUi,
        FontFamilies.sansSerif,
      ]),
      codeFont: FontFamily.list([
        const FontFamily('SF Mono'),
        FontFamilies.uiMonospace,
        FontFamilies.monospace,
      ]),
      docs: DocsThemeExtension(
        shellSurfaceSoft: ThemeColor(
          ThemeColors.zinc.$100,
          dark: const Color('rgba(39, 39, 42, 0.9)'),
        ),
        shellAccent:
            ThemeColor(ThemeColors.indigo.$600, dark: ThemeColors.violet.$300),
        shellAccentStrong:
            ThemeColor(ThemeColors.indigo.$700, dark: ThemeColors.violet.$400),
        shellAccentSoft: const ThemeColor(
          Color('rgba(79, 70, 229, 0.08)'),
          dark: Color('rgba(196, 181, 253, 0.14)'),
        ),
      ),
    );
  }

  factory DocsThemeConfig.forest() {
    return DocsThemeConfig(
      primary:
          ThemeColor(ThemeColors.emerald.$600, dark: ThemeColors.emerald.$300),
      background:
          ThemeColor(ThemeColors.stone.$50, dark: ThemeColors.stone.$950),
      text: ThemeColor(ThemeColors.stone.$700, dark: ThemeColors.stone.$200),
      colors: _contentColors(
        headings:
            ThemeColor(ThemeColors.stone.$950, dark: Colors.white),
        links:
            ThemeColor(ThemeColors.emerald.$700, dark: ThemeColors.emerald.$300),
        lead:
            ThemeColor(ThemeColors.stone.$600, dark: ThemeColors.stone.$400),
        quotes:
            ThemeColor(ThemeColors.stone.$900, dark: ThemeColors.stone.$100),
        quoteBorders:
            ThemeColor(ThemeColors.stone.$300, dark: ThemeColors.stone.$700),
        code:
            ThemeColor(ThemeColors.stone.$950, dark: Colors.white),
        preCode:
            ThemeColor(ThemeColors.stone.$800, dark: ThemeColors.stone.$200),
        preBg: ThemeColor(
          const Color('#f8faf6'),
          dark: ThemeColors.stone.$950,
        ),
        thBorders:
            ThemeColor(ThemeColors.stone.$300, dark: ThemeColors.stone.$700),
        tdBorders:
            ThemeColor(ThemeColors.stone.$200, dark: ThemeColors.stone.$800),
      ),
      typography: _forestTypography(),
      font: FontFamily.list([
        const FontFamily('Charter'),
        FontFamilies.uiSerif,
        FontFamilies.serif,
      ]),
      codeFont: FontFamily.list([
        const FontFamily('IBM Plex Mono'),
        FontFamilies.uiMonospace,
        FontFamilies.monospace,
      ]),
      docs: DocsThemeExtension(
        shellSurfaceSoft: ThemeColor(
          ThemeColors.stone.$100,
          dark: const Color('rgba(41, 37, 36, 0.92)'),
        ),
        shellAccent:
            ThemeColor(ThemeColors.emerald.$600, dark: ThemeColors.emerald.$300),
        shellAccentStrong:
            ThemeColor(ThemeColors.emerald.$700, dark: ThemeColors.emerald.$400),
        shellAccentSoft: const ThemeColor(
          Color('rgba(5, 150, 105, 0.08)'),
          dark: Color('rgba(52, 211, 153, 0.14)'),
        ),
        shellCalloutBg: const ThemeColor(
          Color('rgba(16, 185, 129, 0.08)'),
          dark: Color('rgba(16, 185, 129, 0.14)'),
        ),
        shellCalloutBorder: const ThemeColor(
          Color('rgba(16, 185, 129, 0.55)'),
          dark: Color('rgba(52, 211, 153, 0.7)'),
        ),
      ),
    );
  }

  factory DocsThemeConfig.preset(DocsThemePreset preset) {
    return switch (preset) {
      DocsThemePreset.ocean => DocsThemeConfig.ocean(),
      DocsThemePreset.graphite => DocsThemeConfig.graphite(),
      DocsThemePreset.forest => DocsThemeConfig.forest(),
    };
  }

  final ThemeColor primary;
  final ThemeColor background;
  final ThemeColor text;
  final List<ColorToken> colors;
  final ContentTypography typography;
  final FontFamily font;
  final FontFamily codeFont;
  final DocsThemeExtension docs;

  DocsThemeConfig copyWith({
    ThemeColor? primary,
    ThemeColor? background,
    ThemeColor? text,
    List<ColorToken>? colors,
    ContentTypography? typography,
    FontFamily? font,
    FontFamily? codeFont,
    DocsThemeExtension? docs,
  }) {
    return DocsThemeConfig(
      primary: primary ?? this.primary,
      background: background ?? this.background,
      text: text ?? this.text,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      font: font ?? this.font,
      codeFont: codeFont ?? this.codeFont,
      docs: docs ?? this.docs,
    );
  }

  ContentTheme toContentTheme() {
    return ContentTheme(
      primary: primary,
      background: background,
      text: text,
      colors: colors,
      typography: typography,
      font: font,
      codeFont: codeFont,
      extensions: [docs],
    );
  }
}

class DocsThemeExtension extends ThemeExtension<DocsThemeExtension> {
  DocsThemeExtension({
    ThemeColor? shellSurface,
    ThemeColor? shellSurfaceSoft,
    ThemeColor? shellSurfaceElevated,
    ThemeColor? shellBorder,
    ThemeColor? shellBorderStrong,
    ThemeColor? shellOverlay,
    ThemeColor? shellMuted,
    ThemeColor? shellAccent,
    ThemeColor? shellAccentSoft,
    ThemeColor? shellAccentStrong,
    ThemeColor? shellCalloutBg,
    ThemeColor? shellCalloutBorder,
    ThemeColor? shellCodeButtonBg,
    ThemeColor? shellCodeButtonFg,
    ThemeColor? shellDartPadStage,
    ThemeColor? shellShadow,
    ThemeColor? shellFocus,
  })  : shellSurface = shellSurface ??
            const ThemeColor(
              Colors.white,
              dark: Color('rgba(24, 24, 27, 0.92)'),
            ),
        shellSurfaceSoft = shellSurfaceSoft ??
            ThemeColor(
              ThemeColors.slate.$50,
              dark: const Color('rgba(39, 39, 42, 0.88)'),
            ),
        shellSurfaceElevated = shellSurfaceElevated ??
            ThemeColor(
              Colors.white,
              dark: ThemeColors.zinc.$900,
            ),
        shellBorder = shellBorder ??
            const ThemeColor(
              Color('rgba(148, 163, 184, 0.22)'),
              dark: Color('rgba(148, 163, 184, 0.18)'),
            ),
        shellBorderStrong = shellBorderStrong ??
            const ThemeColor(
              Color('rgba(148, 163, 184, 0.34)'),
              dark: Color('rgba(148, 163, 184, 0.24)'),
            ),
        shellOverlay = shellOverlay ??
            const ThemeColor(
              Color('rgba(15, 23, 42, 0.58)'),
              dark: Color('rgba(2, 6, 23, 0.76)'),
            ),
        shellMuted = shellMuted ??
            const ThemeColor(
              Color('rgba(71, 85, 105, 0.78)'),
              dark: Color('rgba(212, 212, 216, 0.76)'),
            ),
        shellAccent = shellAccent ??
            ThemeColor(
              ThemeColors.blue.$600,
              dark: ThemeColors.sky.$300,
            ),
        shellAccentSoft = shellAccentSoft ??
            const ThemeColor(
              Color('rgba(37, 99, 235, 0.08)'),
              dark: Color('rgba(125, 211, 252, 0.12)'),
            ),
        shellAccentStrong = shellAccentStrong ??
            ThemeColor(
              ThemeColors.blue.$700,
              dark: ThemeColors.sky.$400,
            ),
        shellCalloutBg = shellCalloutBg ??
            const ThemeColor(
              Color('rgba(34, 197, 94, 0.08)'),
              dark: Color('rgba(34, 197, 94, 0.12)'),
            ),
        shellCalloutBorder = shellCalloutBorder ??
            const ThemeColor(
              Color('rgba(34, 197, 94, 0.55)'),
              dark: Color('rgba(74, 222, 128, 0.65)'),
            ),
        shellCodeButtonBg = shellCodeButtonBg ??
            const ThemeColor(
              Color('rgba(15, 23, 42, 0.9)'),
              dark: Color('rgba(39, 39, 42, 0.96)'),
            ),
        shellCodeButtonFg = shellCodeButtonFg ??
            const ThemeColor(
              Colors.white,
              dark: Color('#fafafa'),
            ),
        shellDartPadStage = shellDartPadStage ??
            const ThemeColor(
              Colors.white,
              dark: Color('#0b1120'),
            ),
        shellShadow = shellShadow ??
            const ThemeColor(
              Color('rgba(15, 23, 42, 0.18)'),
              dark: Color('rgba(2, 6, 23, 0.45)'),
            ),
        shellFocus = shellFocus ??
            const ThemeColor(
              Color('rgba(37, 99, 235, 0.18)'),
              dark: Color('rgba(125, 211, 252, 0.18)'),
            );

  final ThemeColor shellSurface;
  final ThemeColor shellSurfaceSoft;
  final ThemeColor shellSurfaceElevated;
  final ThemeColor shellBorder;
  final ThemeColor shellBorderStrong;
  final ThemeColor shellOverlay;
  final ThemeColor shellMuted;
  final ThemeColor shellAccent;
  final ThemeColor shellAccentSoft;
  final ThemeColor shellAccentStrong;
  final ThemeColor shellCalloutBg;
  final ThemeColor shellCalloutBorder;
  final ThemeColor shellCodeButtonBg;
  final ThemeColor shellCodeButtonFg;
  final ThemeColor shellDartPadStage;
  final ThemeColor shellShadow;
  final ThemeColor shellFocus;

  @override
  DocsThemeExtension copyWith({
    ThemeColor? shellSurface,
    ThemeColor? shellSurfaceSoft,
    ThemeColor? shellSurfaceElevated,
    ThemeColor? shellBorder,
    ThemeColor? shellBorderStrong,
    ThemeColor? shellOverlay,
    ThemeColor? shellMuted,
    ThemeColor? shellAccent,
    ThemeColor? shellAccentSoft,
    ThemeColor? shellAccentStrong,
    ThemeColor? shellCalloutBg,
    ThemeColor? shellCalloutBorder,
    ThemeColor? shellCodeButtonBg,
    ThemeColor? shellCodeButtonFg,
    ThemeColor? shellDartPadStage,
    ThemeColor? shellShadow,
    ThemeColor? shellFocus,
  }) {
    return DocsThemeExtension(
      shellSurface: shellSurface ?? this.shellSurface,
      shellSurfaceSoft: shellSurfaceSoft ?? this.shellSurfaceSoft,
      shellSurfaceElevated:
          shellSurfaceElevated ?? this.shellSurfaceElevated,
      shellBorder: shellBorder ?? this.shellBorder,
      shellBorderStrong: shellBorderStrong ?? this.shellBorderStrong,
      shellOverlay: shellOverlay ?? this.shellOverlay,
      shellMuted: shellMuted ?? this.shellMuted,
      shellAccent: shellAccent ?? this.shellAccent,
      shellAccentSoft: shellAccentSoft ?? this.shellAccentSoft,
      shellAccentStrong: shellAccentStrong ?? this.shellAccentStrong,
      shellCalloutBg: shellCalloutBg ?? this.shellCalloutBg,
      shellCalloutBorder: shellCalloutBorder ?? this.shellCalloutBorder,
      shellCodeButtonBg: shellCodeButtonBg ?? this.shellCodeButtonBg,
      shellCodeButtonFg: shellCodeButtonFg ?? this.shellCodeButtonFg,
      shellDartPadStage: shellDartPadStage ?? this.shellDartPadStage,
      shellShadow: shellShadow ?? this.shellShadow,
      shellFocus: shellFocus ?? this.shellFocus,
    );
  }

  @override
  Map<String, Object> buildVariables(ContentTheme theme) {
    return {
      '--docs-shell-surface': shellSurface,
      '--docs-shell-surface-soft': shellSurfaceSoft,
      '--docs-shell-surface-elevated': shellSurfaceElevated,
      '--docs-shell-border': shellBorder,
      '--docs-shell-border-strong': shellBorderStrong,
      '--docs-shell-overlay': shellOverlay,
      '--docs-shell-muted': shellMuted,
      '--docs-shell-accent': shellAccent,
      '--docs-shell-accent-soft': shellAccentSoft,
      '--docs-shell-accent-strong': shellAccentStrong,
      '--docs-shell-callout-bg': shellCalloutBg,
      '--docs-shell-callout-border': shellCalloutBorder,
      '--docs-shell-code-button-bg': shellCodeButtonBg,
      '--docs-shell-code-button-fg': shellCodeButtonFg,
      '--docs-shell-dartpad-stage': shellDartPadStage,
      '--docs-shell-shadow': shellShadow,
      '--docs-shell-focus': shellFocus,
    };
  }
}

List<ColorToken> _contentColors({
  required ThemeColor headings,
  required ThemeColor links,
  required ThemeColor lead,
  required ThemeColor quotes,
  required ThemeColor quoteBorders,
  required ThemeColor code,
  required ThemeColor preCode,
  required ThemeColor preBg,
  required ThemeColor thBorders,
  required ThemeColor tdBorders,
}) {
  return [
    ContentColors.headings.apply(headings),
    ContentColors.links.apply(links),
    ContentColors.bold.apply(headings),
    ContentColors.lead.apply(lead),
    ContentColors.quotes.apply(quotes),
    ContentColors.quoteBorders.apply(quoteBorders),
    ContentColors.code.apply(code),
    ContentColors.preCode.apply(preCode),
    ContentColors.preBg.apply(preBg),
    ContentColors.thBorders.apply(thBorders),
    ContentColors.tdBorders.apply(tdBorders),
  ];
}

ContentTypography _oceanTypography() {
  return ContentTypography.base.apply(
    rules: [
      css('h1').styles(raw: {'letter-spacing': '-0.03em'}),
      css('h2, h3').styles(raw: {'scroll-margin-top': '5rem'}),
      css('p, li').styles(raw: {'line-height': '1.72'}),
    ],
  );
}

ContentTypography _graphiteTypography() {
  return ContentTypography.base.apply(
    rules: [
      css('h1').styles(
        fontWeight: FontWeight.w900,
        raw: {'letter-spacing': '-0.045em'},
      ),
      css('h2').styles(raw: {'letter-spacing': '-0.03em'}),
      css('h2, h3').styles(raw: {'scroll-margin-top': '5rem'}),
      css('p, li').styles(raw: {'line-height': '1.68'}),
      css('blockquote').styles(fontStyle: FontStyle.normal),
    ],
  );
}

ContentTypography _forestTypography() {
  return ContentTypography.base.apply(
    rules: [
      css('h1').styles(
        fontWeight: FontWeight.w800,
        raw: {'letter-spacing': '-0.02em'},
      ),
      css('h2').styles(fontWeight: FontWeight.w700),
      css('h2, h3').styles(raw: {'scroll-margin-top': '5rem'}),
      css('p, li').styles(raw: {'line-height': '1.8'}),
      css('blockquote').styles(fontStyle: FontStyle.normal),
    ],
  );
}
