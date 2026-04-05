import 'package:jaspr/dom.dart';
import 'package:jaspr_content/theme.dart';

import '../theme/docs_responsive.dart';

List<StyleRule> docsHeaderShellStyles() => [
  css('.docs .header-container', [
    css('&').styles(
      position: Position.sticky(top: Unit.zero),
      zIndex: ZIndex(40),
      backgroundColor: Color('rgba(255, 255, 255, 0.74)'),
      border: Border.only(
        bottom: BorderSide(
          width: 1.px,
          color: Color('rgba(148, 163, 184, 0.18)'),
        ),
      ),
      raw: {
        'backdrop-filter': 'blur(8px)',
        '-webkit-backdrop-filter': 'blur(8px)',
        'box-shadow': '0 14px 36px -28px var(--docs-shell-shadow)',
      },
    ),
    css('.header').styles(
      maxWidth: 100.percent,
      margin: Margin.zero,
      raw: {
        'margin-left': 'auto',
        'margin-right': 'auto',
        'max-width': 'var(--docs-shell-main-max-width)',
        'padding-block': 'var(--docs-shell-header-block-pad)',
        'padding-inline': 'var(--docs-shell-header-inline-pad)',
      },
    ),
    css(
      '.header .header-title',
    ).styles(fontWeight: FontWeight.w800, raw: {'letter-spacing': '-0.03em'}),
  ]),
  css('.theme-toggle').styles(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    justifyContent: JustifyContent.center,
    width: 2.6.rem,
    height: 2.6.rem,
    padding: Padding.zero,
    border: Border.all(width: 1.px, color: Color('var(--docs-shell-border)')),
    radius: BorderRadius.circular(999.px),
    backgroundColor: Color('var(--docs-shell-surface-soft)'),
    color: ContentColors.text,
    cursor: Cursor.pointer,
    shadow: BoxShadow(
      offsetX: Unit.zero,
      offsetY: 10.px,
      blur: 20.px,
      color: Color('var(--docs-shell-shadow)'),
    ),
    transition: Transition(
      'background-color, border-color, transform, box-shadow',
      duration: Duration(milliseconds: 170),
    ),
  ),
  css('.theme-toggle-icon').styles(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    justifyContent: JustifyContent.center,
    fontSize: 1.rem,
    raw: {'line-height': '1'},
  ),
  css('.theme-toggle:hover').styles(
    backgroundColor: Color('var(--docs-shell-accent-soft)'),
    border: Border.all(
      width: 1.px,
      color: Color('var(--docs-shell-border-strong)'),
    ),
    raw: {'transform': 'translateY(-1px)'},
    shadow: BoxShadow(
      offsetX: Unit.zero,
      offsetY: 14.px,
      blur: 24.px,
      color: Color('var(--docs-shell-shadow)'),
    ),
  ),
  css('.header-search-shell', [
    css('&').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      justifyContent: JustifyContent.end,
      padding: Padding.zero,
      margin: Margin.zero,
      minWidth: Unit.zero,
      maxWidth: Unit.auto,
    ),
    css('.search-launcher').styles(
      display: Display.flex,
      justifyContent: JustifyContent.spaceBetween,
      alignItems: AlignItems.center,
      gap: Gap.column(0.55.rem),
      minWidth: 0.rem,
      padding: Padding.symmetric(vertical: 0.46.rem, horizontal: 0.72.rem),
      border: Border.all(
        width: 1.px,
        color: Color('var(--docs-shell-border-strong)'),
      ),
      radius: BorderRadius.circular(999.px),
      backgroundColor: Color('var(--docs-shell-surface)'),
      cursor: Cursor.pointer,
      color: ContentColors.text,
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: 8.px,
        blur: 16.px,
        color: Color('var(--docs-shell-shadow)'),
      ),
      transition: Transition(
        'border-color, background-color, transform',
        duration: Duration(milliseconds: 150),
      ),
      raw: {
        'position': 'relative',
        'flex': '0 1 auto',
        'max-width': '100%',
        'min-width': 'var(--docs-shell-search-launcher-min)',
        'backdrop-filter': 'blur(8px)',
        '-webkit-backdrop-filter': 'blur(8px)',
      },
    ),
    css('.search-launcher::before').styles(
      display: Display.none,
      raw: {'content': '"⌕"', 'font-size': '0.82rem', 'line-height': '1'},
    ),
    css('.search-launcher:hover').styles(
      border: Border.all(width: 1.px, color: Color('var(--docs-shell-accent)')),
      backgroundColor: Color('var(--docs-shell-accent-soft)'),
      raw: {'transform': 'translateY(-1px)'},
    ),
    css('.search-launcher:focus-visible').styles(
      outline: Outline(
        width: OutlineWidth(3.px),
        style: OutlineStyle.solid,
        color: Color('var(--docs-shell-focus)'),
        offset: 2.px,
      ),
    ),
    css(
      '.search-launcher-label',
    ).styles(fontWeight: FontWeight.w700, fontSize: 0.95.rem),
    css('.search-launcher-shortcut').styles(
      fontSize: 0.74.rem,
      opacity: 0.7,
      padding: Padding.symmetric(vertical: 0.12.rem, horizontal: 0.32.rem),
      radius: BorderRadius.circular(999.px),
      backgroundColor: Color('var(--docs-shell-surface-elevated)'),
      raw: {'line-height': '1'},
    ),
    downMobile([
      css('&').styles(justifyContent: JustifyContent.end),
      css('.search-launcher').styles(
        minWidth: 0.rem,
        gap: Gap.column(0.55.rem),
        padding: Padding.symmetric(vertical: 0.54.rem, horizontal: 0.72.rem),
        raw: {'min-width': 'var(--docs-shell-search-launcher-min)'},
      ),
      css('.search-launcher-label').styles(fontSize: 0.88.rem),
      css('.search-launcher-shortcut').styles(
        fontSize: 0.75.rem,
        padding: Padding.symmetric(vertical: 0.14.rem, horizontal: 0.34.rem),
      ),
    ]),
    downCompact([
      css(
        '&',
      ).styles(justifyContent: JustifyContent.end, raw: {'flex': '0 0 auto'}),
      css('.search-launcher').styles(
        minWidth: 0.rem,
        gap: Gap.column(0.38.rem),
        padding: Padding.symmetric(vertical: 0.5.rem, horizontal: 0.62.rem),
        raw: {
          'width': 'var(--docs-shell-search-launcher-min)',
          'max-width': 'var(--docs-shell-search-launcher-min)',
          'justify-content': 'center',
        },
      ),
      css('.search-launcher::before').styles(
        display: Display.inlineFlex,
        justifyContent: JustifyContent.center,
        alignItems: AlignItems.center,
      ),
      css('.search-launcher-label').styles(display: Display.none),
      css('.search-launcher-shortcut').styles(display: Display.none),
    ]),
  ]),
  css(
    '[data-theme="dark"] .header-search-shell .search-launcher-shortcut',
  ).styles(opacity: 0.6),
  downContent([
    css('.header-search-shell').styles(
      justifyContent: JustifyContent.end,
      raw: {'flex': '0 0 auto'},
    ),
    css('.header-search-shell .search-launcher').styles(
      minWidth: 0.rem,
      gap: Gap.column(0.42.rem),
      padding: Padding.symmetric(vertical: 0.5.rem, horizontal: 0.72.rem),
      raw: {'min-width': 'auto'},
    ),
    css('.header-search-shell .search-launcher-label').styles(
      fontSize: 0.92.rem,
    ),
    css('.header-search-shell .search-launcher-shortcut').styles(
      display: Display.none,
    ),
  ]),
  downMobile([
    css('.theme-toggle').styles(width: 2.45.rem, height: 2.45.rem),
  ]),
  downCompact([
    css('.theme-toggle').styles(width: 2.3.rem, height: 2.3.rem),
    css('.theme-toggle-icon').styles(fontSize: 0.92.rem),
  ]),
  css('[data-theme="dark"] .docs .header-container').styles(
    backgroundColor: Color('rgba(24, 24, 27, 0.74)'),
    border: Border.only(
      bottom: BorderSide(
        width: 1.px,
        color: Color('rgba(148, 163, 184, 0.14)'),
      ),
    ),
  ),
  css('.version-switch').styles(
    display: Display.flex,
    alignItems: AlignItems.center,
    border: Border.all(
      width: 1.px,
      color: Color('var(--docs-shell-border-strong)'),
    ),
    radius: BorderRadius.circular(999.px),
    backgroundColor: Color('var(--docs-shell-surface-soft)'),
    padding: Padding.all(0.2.rem),
    gap: Gap.column(Unit.zero),
  ),
  css('.version-switch-option').styles(
    display: Display.inlineFlex,
    alignItems: AlignItems.center,
    justifyContent: JustifyContent.center,
    padding: Padding.symmetric(vertical: 0.32.rem, horizontal: 0.85.rem),
    fontSize: 0.82.rem,
    fontWeight: FontWeight.w700,
    radius: BorderRadius.circular(999.px),
    textDecoration: TextDecoration.none,
    color: Color('var(--docs-shell-muted)'),
    transition: Transition(
      'background-color, color',
      duration: Duration(milliseconds: 150),
    ),
    raw: {'white-space': 'nowrap'},
  ),
  css('.version-switch-option:hover').styles(
    color: ContentColors.text,
  ),
  css('.version-switch-option.is-active').styles(
    backgroundColor: Color('var(--docs-shell-accent)'),
    color: Color('white'),
    shadow: BoxShadow(
      offsetX: Unit.zero,
      offsetY: 2.px,
      blur: 8.px,
      color: Color('var(--docs-shell-shadow)'),
    ),
  ),
];
