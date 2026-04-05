import 'package:jaspr/dom.dart';
import 'package:jaspr_content/theme.dart';

import '../theme/docs_responsive.dart';

List<StyleRule> docsSearchStyles() => [
    css('.docs-search-overlay', [
      css('&').styles(
        position: Position.fixed(
          top: Unit.zero,
          left: Unit.zero,
          right: Unit.zero,
          bottom: Unit.zero,
        ),
        zIndex: ZIndex(90),
        raw: {'pointer-events': 'none', 'padding': '0 1rem'},
      ),
      css('&[hidden]').styles(display: Display.none),
      css('.docs-search-backdrop').styles(
        position: Position.absolute(
          top: Unit.zero,
          left: Unit.zero,
          right: Unit.zero,
          bottom: Unit.zero,
        ),
        backgroundColor: Color('var(--docs-shell-overlay)'),
        zIndex: ZIndex(0),
        raw: {'pointer-events': 'auto'},
      ),
      css('.docs-search-panel').styles(
        position: Position.relative(),
        margin: Margin.only(top: 7.vh),
        width: 100.percent,
        maxWidth: 100.percent,
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        radius: BorderRadius.circular(1.15.rem),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 22.px,
          blur: 42.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        overflow: Overflow.hidden,
        raw: {
          'margin-left': 'auto',
          'margin-right': 'auto',
          'max-width': 'var(--docs-shell-search-panel-width)',
          'z-index': '1',
          'backdrop-filter': 'blur(18px)',
          '-webkit-backdrop-filter': 'blur(18px)',
          'pointer-events': 'auto',
        },
      ),
      css('.docs-search-header').styles(
        display: Display.grid,
        alignItems: AlignItems.center,
        gap: Gap.column(0.65.rem),
        padding: Padding.only(
          top: 1.05.rem,
          right: 1.05.rem,
          bottom: 0.9.rem,
          left: 1.05.rem,
        ),
        border: Border.only(
          bottom: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
        raw: {
          'grid-template-columns': 'minmax(0, 1fr) auto',
          'grid-template-areas': '"heading heading" "input close"',
        },
      ),
      css('.docs-search-heading').styles(
        width: 100.percent,
        fontSize: 0.84.rem,
        fontWeight: FontWeight.w800,
        textTransform: TextTransform.upperCase,
        color: Color('var(--docs-shell-muted)'),
        raw: {'grid-area': 'heading', 'letter-spacing': '0.12em'},
      ),
      css('.docs-search-input').styles(
        raw: {'grid-area': 'input'},
        width: 100.percent,
        padding: Padding.symmetric(vertical: 0.84.rem, horizontal: 0.98.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        radius: BorderRadius.circular(0.82.rem),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        color: ContentColors.text,
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 10.px,
          blur: 22.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
      ),
      css('.docs-search-input:focus-visible').styles(
        outline: Outline(
          width: OutlineWidth(3.px),
          style: OutlineStyle.solid,
          color: Color('var(--docs-shell-focus)'),
          offset: 1.px,
        ),
      ),
      css('.docs-search-close').styles(
        raw: {'grid-area': 'close'},
        alignSelf: AlignSelf.center,
        padding: Padding.symmetric(vertical: 0.48.rem, horizontal: 0.74.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        radius: BorderRadius.circular(0.82.rem),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        cursor: Cursor.pointer,
        color: ContentColors.text,
      ),
      css('.docs-search-close:hover').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-accent)'),
        ),
      ),
      css('.docs-search-status').styles(
        padding: Padding.symmetric(vertical: 0.72.rem, horizontal: 1.05.rem),
        fontSize: 0.88.rem,
        color: Color('var(--docs-shell-muted)'),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
      ),
      css(
        '.docs-search-status[data-search-state="loading"]',
      ).styles(color: Color('var(--docs-shell-accent-strong)')),
      css('.docs-search-status[data-search-state="error"]').styles(
        color: Color('var(--docs-shell-accent-strong)'),
        backgroundColor: Color('var(--docs-shell-callout-bg)'),
      ),
      css('.docs-search-results').styles(
        maxHeight: 65.vh,
        overflow: Overflow.auto,
        padding: Padding.only(
          top: 0.42.rem,
          right: 0.42.rem,
          bottom: 0.5.rem,
          left: 0.42.rem,
        ),
        backgroundColor: Color('var(--docs-shell-surface)'),
      ),
      css('.docs-search-empty-state').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        gap: Gap.column(0.95.rem),
        padding: Padding.symmetric(vertical: 1.1.rem, horizontal: 1.05.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        radius: BorderRadius.circular(1.rem),
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
      ),
      css('.docs-search-empty-icon').styles(
        display: Display.inlineFlex,
        justifyContent: JustifyContent.center,
        alignItems: AlignItems.center,
        width: 2.35.rem,
        height: 2.35.rem,
        fontSize: 1.05.rem,
        fontWeight: FontWeight.w800,
        radius: BorderRadius.circular(999.px),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
        raw: {'flex': '0 0 auto'},
      ),
      css(
        '.docs-search-empty-copy',
      ).styles(minWidth: Unit.zero, raw: {'flex': '1 1 auto'}),
      css('.docs-search-empty-title').styles(
        fontWeight: FontWeight.w700,
        margin: Margin.only(bottom: 0.16.rem),
      ),
      css('.docs-search-empty-text').styles(
        fontSize: 0.9.rem,
        color: Color('var(--docs-shell-muted)'),
        raw: {'line-height': '1.55'},
      ),
      css('.docs-search-footer').styles(
        display: Display.flex,
        justifyContent: JustifyContent.spaceBetween,
        alignItems: AlignItems.center,
        flexWrap: FlexWrap.wrap,
        gap: Gap.row(0.75.rem),
        padding: Padding.symmetric(vertical: 0.72.rem, horizontal: 0.95.rem),
        border: Border.only(
          top: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
      ),
      css('.docs-search-hints').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        flexWrap: FlexWrap.wrap,
        gap: Gap.column(0.45.rem),
      ),
      css('.docs-search-key').styles(
        display: Display.inlineFlex,
        justifyContent: JustifyContent.center,
        alignItems: AlignItems.center,
        minWidth: 2.rem,
        padding: Padding.symmetric(vertical: 0.22.rem, horizontal: 0.4.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        radius: BorderRadius.circular(0.5.rem),
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        color: ContentColors.text,
        fontSize: 0.76.rem,
        fontWeight: FontWeight.w700,
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 10.px,
          blur: 24.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
      ),
      css(
        '.docs-search-hint-label, .docs-search-footnote',
      ).styles(fontSize: 0.82.rem, color: Color('var(--docs-shell-muted)')),
      css('.docs-search-result').styles(
        display: Display.flex,
        gap: Gap.column(1.rem),
        margin: Margin.only(bottom: 0.45.rem),
        padding: Padding.symmetric(vertical: 0.84.rem, horizontal: 0.95.rem),
        textDecoration: TextDecoration.none,
        color: ContentColors.text,
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        radius: BorderRadius.circular(0.95.rem),
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        transition: Transition(
          'background-color, border-color, transform, box-shadow',
          duration: Duration(milliseconds: 150),
        ),
      ),
      css(
        '.docs-search-result:last-child',
      ).styles(margin: Margin.only(bottom: Unit.zero)),
      css('.docs-search-result:hover').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        raw: {'transform': 'translateY(-1px)'},
      ),
      css('.docs-search-result.active').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-accent)'),
        ),
        shadow: BoxShadow(
          offsetX: Unit.zero,
          offsetY: 16.px,
          blur: 28.px,
          color: Color('var(--docs-shell-shadow)'),
        ),
        raw: {
          'outline': '1px solid var(--docs-shell-accent)',
          'box-shadow':
              'inset 3px 0 0 var(--docs-shell-accent), 0 16px 28px var(--docs-shell-shadow)',
        },
      ),
      css('.docs-search-result:focus-visible').styles(
        outline: Outline(
          width: OutlineWidth(3.px),
          style: OutlineStyle.solid,
          color: Color('var(--docs-shell-focus)'),
        ),
        raw: {'outline-offset': '-2px'},
      ),
      css(
        '.docs-search-result-section',
      ).styles(backgroundColor: Color('var(--docs-shell-surface-soft)')),
      css('.docs-search-kind').styles(
        display: Display.inlineFlex,
        justifyContent: JustifyContent.center,
        alignItems: AlignItems.center,
        minWidth: 3.5.rem,
        padding: Padding.symmetric(vertical: 0.28.rem, horizontal: 0.55.rem),
        fontSize: 0.72.rem,
        fontWeight: FontWeight.w700,
        textTransform: TextTransform.upperCase,
        radius: BorderRadius.circular(999.px),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
      ),
      css('.docs-search-meta').styles(flex: Flex(grow: 1)),
      css('.docs-search-topline').styles(
        display: Display.flex,
        justifyContent: JustifyContent.spaceBetween,
        alignItems: AlignItems.center,
        flexWrap: FlexWrap.wrap,
        gap: Gap.row(0.6.rem),
        margin: Margin.only(bottom: 0.35.rem),
      ),
      css('.docs-search-title').styles(
        fontWeight: FontWeight.w700,
        margin: Margin.only(bottom: 0.24.rem),
        raw: {'line-height': '1.32'},
      ),
      css('.docs-search-title mark, .docs-search-summary mark').styles(
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        color: Color('var(--docs-shell-accent-strong)'),
        radius: BorderRadius.circular(0.35.rem),
        padding: Padding.symmetric(vertical: 0.04.rem, horizontal: Unit.zero),
        raw: {
          'box-decoration-break': 'clone',
          '-webkit-box-decoration-break': 'clone',
        },
      ),
      css('.docs-search-section').styles(
        fontWeight: FontWeight.w500,
        opacity: 0.8,
        margin: Margin.only(left: 0.35.rem),
      ),
      css('.docs-search-url').styles(
        fontSize: 0.8.rem,
        color: Color('var(--docs-shell-muted)'),
        raw: {'word-break': 'break-word'},
      ),
      css('.docs-search-summary').styles(
        fontSize: 0.89.rem,
        opacity: 0.9,
        color: Color('var(--docs-shell-muted)'),
        raw: {
          'line-height': '1.48',
          'display': '-webkit-box',
          '-webkit-box-orient': 'vertical',
          '-webkit-line-clamp': '2',
          'overflow': 'hidden',
        },
      ),
      css('.docs-search-kind-guide').styles(
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        color: Color('var(--docs-shell-accent)'),
      ),
      css('.docs-search-kind-page').styles(
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        color: Color('var(--docs-shell-accent)'),
      ),
      css('.docs-search-kind-section').styles(
        backgroundColor: Color('var(--docs-shell-callout-bg)'),
        color: Color('var(--docs-shell-accent-strong)'),
      ),
      downMobile([
        css('.docs-search-panel').styles(
          margin: Margin.only(top: 2.5.vh),
          maxWidth: 100.percent,
          raw: {'margin-left': '0.55rem', 'margin-right': '0.55rem'},
        ),
        css('.docs-search-header').styles(
          display: Display.block,
          raw: {'grid-template-columns': 'none', 'grid-template-areas': 'none'},
        ),
        css(
          '.docs-search-heading',
        ).styles(margin: Margin.only(bottom: 0.8.rem)),
        css('.docs-search-close').styles(margin: Margin.only(top: 0.65.rem)),
        css('.docs-search-footer').styles(display: Display.block),
        css('.docs-search-footnote').styles(
          display: Display.block,
          margin: Margin.only(top: 0.65.rem),
        ),
        css('.docs-search-result').styles(
          display: Display.block,
          padding: Padding.symmetric(vertical: 0.78.rem, horizontal: 0.82.rem),
        ),
        css('.docs-search-empty-state').styles(
          display: Display.block,
          padding: Padding.symmetric(vertical: 0.95.rem, horizontal: 0.9.rem),
        ),
        css(
          '.docs-search-empty-icon',
        ).styles(margin: Margin.only(bottom: 0.55.rem)),
        css('.docs-search-kind').styles(margin: Margin.only(bottom: 0.4.rem)),
        css('.docs-search-topline').styles(display: Display.block),
        css('.docs-search-url').styles(margin: Margin.only(top: 0.3.rem)),
      ]),
    ]),
  ];
