import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';
import '../theme/docs_responsive.dart';

class DocsHomeHeroAction {
  const DocsHomeHeroAction({
    required this.text,
    required this.href,
    required this.theme,
    this.isExternal = false,
  });

  final String text;
  final String href;
  final String theme;
  final bool isExternal;
}

class DocsHomeHero extends StatelessComponent {
  const DocsHomeHero({
    required this.name,
    required this.text,
    required this.tagline,
    required this.actions,
    super.key,
  });

  final String name;
  final String text;
  final String tagline;
  final List<DocsHomeHeroAction> actions;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      section(classes: 'docs-home-hero', [
        div(classes: 'docs-home-hero-copy', [
          div(classes: 'docs-home-hero-eyebrow', [
            Component.text('Jaspr Documentation'),
          ]),
          h1(classes: 'docs-home-hero-name', [Component.text(name)]),
          p(classes: 'docs-home-hero-text', [Component.text(text)]),
          p(classes: 'docs-home-hero-tagline', [Component.text(tagline)]),
          if (actions.isNotEmpty)
            div(classes: 'docs-home-hero-actions', [
              for (final action in actions)
                DocsNavLink(
                  to: action.href,
                  target: action.isExternal ? Target.blank : null,
                  attributes: {if (action.isExternal) 'rel': 'noopener'},
                  classes: action.theme == 'brand'
                      ? 'docs-home-hero-action is-brand'
                      : 'docs-home-hero-action is-alt',
                  children: [Component.text(action.text)],
                ),
            ]),
        ]),
        div(classes: 'docs-home-hero-scene', [
          div(classes: 'docs-home-doc', [
            div(classes: 'docs-home-doc-face docs-home-doc-front', [
              div(classes: 'docs-home-doc-header', [
                span(classes: 'docs-home-doc-dot is-danger', const []),
                span(classes: 'docs-home-doc-dot is-warning', const []),
                span(classes: 'docs-home-doc-dot is-success', const []),
              ]),
              div(classes: 'docs-home-doc-body', [
                div(classes: 'docs-home-doc-line is-keyword', const []),
                div(classes: 'docs-home-doc-line is-type', const []),
                div(classes: 'docs-home-doc-line is-wide', const []),
                div(classes: 'docs-home-doc-line is-function', const []),
                div(classes: 'docs-home-doc-line is-mid', const []),
                div(classes: 'docs-home-doc-line is-short', const []),
                div(classes: 'docs-home-doc-line is-keyword', const []),
                div(classes: 'docs-home-doc-line is-type is-long', const []),
              ]),
              div(classes: 'docs-home-doc-badge is-api', [
                Component.text('API'),
              ]),
            ]),
            div(classes: 'docs-home-doc-face docs-home-doc-back', [
              div(classes: 'docs-home-doc-header', [
                span(classes: 'docs-home-doc-dot is-danger', const []),
                span(classes: 'docs-home-doc-dot is-warning', const []),
                span(classes: 'docs-home-doc-dot is-success', const []),
              ]),
              div(classes: 'docs-home-doc-body', [
                div(classes: 'docs-home-doc-line is-wide', const []),
                div(classes: 'docs-home-doc-line is-mid', const []),
                div(classes: 'docs-home-doc-line is-long', const []),
                div(classes: 'docs-home-doc-line is-short', const []),
                div(classes: 'docs-home-doc-line is-type', const []),
              ]),
              div(classes: 'docs-home-doc-badge is-guide', [
                Component.text('Guide'),
              ]),
            ]),
          ]),
          span(classes: 'docs-home-particle p-one', [Component.text('{}')]),
          span(classes: 'docs-home-particle p-two', [Component.text('</>')]),
          span(classes: 'docs-home-particle p-three', [Component.text('///')]),
          span(classes: 'docs-home-particle p-four', [Component.text('.md')]),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get _styles => [
    css.keyframes('docs-home-doc-rotate', {
      '0%, 100%': const Styles(
        raw: {'transform': 'rotateY(-16deg) rotateX(5deg) translateY(0)'},
      ),
      '25%': const Styles(
        raw: {'transform': 'rotateY(12deg) rotateX(-2deg) translateY(-10px)'},
      ),
      '50%': const Styles(
        raw: {'transform': 'rotateY(194deg) rotateX(4deg) translateY(0)'},
      ),
      '75%': const Styles(
        raw: {'transform': 'rotateY(168deg) rotateX(-2deg) translateY(-10px)'},
      ),
    }),
    css.keyframes('docs-home-particle-float', {
      '0%, 100%': const Styles(
        opacity: 0,
        raw: {'transform': 'translateY(10px)'},
      ),
      '15%, 85%': const Styles(opacity: 0.62),
      '50%': const Styles(
        opacity: 0.88,
        raw: {'transform': 'translateY(-16px)'},
      ),
    }),
    css.keyframes('docs-home-hero-glow', {
      '0%': const Styles(
        opacity: 0.56,
        raw: {'transform': 'translateX(-50%) scale(1)'},
      ),
      '100%': const Styles(
        opacity: 1,
        raw: {'transform': 'translateX(-50%) scale(1.16)'},
      ),
    }),
    css('.docs-home-hero', [
      css('&').styles(
        display: Display.grid,
        alignItems: AlignItems.center,
        gap: Gap.all(2.5.rem),
        raw: {
          'grid-template-columns': 'minmax(0, 1.15fr) minmax(18rem, 25rem)',
          'position': 'relative',
          'isolation': 'isolate',
        },
      ),
      css('&::before').styles(
        content: '""',
        position: Position.absolute(top: (-5).percent, left: 50.percent),
        width: 38.rem,
        height: 38.rem,
        radius: BorderRadius.circular(999.px),
        pointerEvents: PointerEvents.none,
        filter: Filter.blur(64.px),
        opacity: 0.9,
        zIndex: ZIndex(-1),
        raw: {
          'background':
              'radial-gradient(circle, color-mix(in srgb, var(--docs-shell-accent) 18%, transparent) 0%, color-mix(in srgb, var(--docs-shell-accent-strong) 10%, transparent) 42%, transparent 72%)',
          'transform': 'translateX(-50%)',
          'animation': 'docs-home-hero-glow 6s ease-in-out infinite alternate',
        },
      ),
      css('.docs-home-hero-copy').styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        alignItems: AlignItems.start,
        raw: {'min-width': '0'},
      ),
      css('.docs-home-hero-eyebrow').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        padding: Padding.symmetric(horizontal: 0.8.rem, vertical: 0.38.rem),
        margin: Margin.only(bottom: 1.rem),
        radius: BorderRadius.circular(999.px),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        color: Color('var(--docs-shell-accent-strong)'),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        fontWeight: FontWeight.w700,
        fontSize: 0.76.rem,
        textTransform: TextTransform.upperCase,
        letterSpacing: 0.12.rem,
      ),
      css('.docs-home-hero-name').styles(
        margin: Margin.zero,
        fontSize: 3.65.rem,
        fontWeight: FontWeight.w900,
        color: ContentColors.headings,
        raw: {
          'line-height': '1.02',
          'letter-spacing': '-0.055em',
          'max-width': '12ch',
          'text-wrap': 'balance',
        },
      ),
      css('.docs-home-hero-text').styles(
        margin: Margin.only(top: 0.9.rem),
        fontSize: 1.34.rem,
        fontWeight: FontWeight.w700,
        color: Color('var(--docs-shell-accent-strong)'),
        raw: {'letter-spacing': '-0.025em'},
      ),
      css('.docs-home-hero-tagline').styles(
        margin: Margin.only(top: 0.95.rem),
        maxWidth: 34.rem,
        fontSize: 1.05.rem,
        color: Color('var(--docs-shell-muted)'),
        raw: {'line-height': '1.72', 'text-wrap': 'pretty'},
      ),
      css('.docs-home-hero-actions').styles(
        display: Display.flex,
        flexWrap: FlexWrap.wrap,
        gap: Gap.all(0.9.rem),
        margin: Margin.only(top: 1.6.rem),
      ),
      css('.docs-home-hero-action').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        minHeight: 3.1.rem,
        padding: Padding.symmetric(horizontal: 1.15.rem, vertical: 0.72.rem),
        radius: BorderRadius.circular(1.rem),
        border: Border.all(width: 1.px, color: Color('transparent')),
        fontWeight: FontWeight.w700,
        transition: Transition(
          'transform, box-shadow, background-color, border-color, color',
          duration: 180.ms,
          curve: Curve.easeInOut,
        ),
        raw: {'box-shadow': '0 18px 38px rgba(15, 23, 42, 0.08)'},
      ),
      css(
        '.docs-home-hero-action:hover',
      ).styles(raw: {'transform': 'translateY(-1px)'}),
      css('.docs-home-hero-action:focus-visible').styles(
        outline: Outline(
          width: OutlineWidth(3.px),
          style: OutlineStyle.solid,
          color: Color('var(--docs-shell-focus)'),
          offset: 3.px,
        ),
      ),
      css('.docs-home-hero-action.is-brand').styles(
        color: Colors.white,
        backgroundColor: Color('var(--docs-shell-accent-strong)'),
      ),
      css(
        '.docs-home-hero-action.is-brand:hover',
      ).styles(backgroundColor: Color('var(--docs-shell-accent)')),
      css('.docs-home-hero-action.is-alt').styles(
        color: ContentColors.headings,
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
      ),
      css('.docs-home-hero-action.is-alt:hover').styles(
        color: Color('var(--docs-shell-accent-strong)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
      ),
      css('.docs-home-hero-scene').styles(
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        position: Position.relative(),
        width: 100.percent,
        height: 21.rem,
        raw: {'perspective': '900px'},
      ),
      css('.docs-home-doc').styles(
        position: Position.relative(),
        width: 14.2.rem,
        height: 18.2.rem,
        raw: {
          'transform-style': 'preserve-3d',
          'animation': 'docs-home-doc-rotate 8s ease-in-out infinite',
        },
      ),
      css('.docs-home-doc-face').styles(
        position: Position.absolute(
          top: Unit.zero,
          right: Unit.zero,
          bottom: Unit.zero,
          left: Unit.zero,
        ),
        display: Display.flex,
        flexDirection: FlexDirection.column,
        padding: Padding.all(1.05.rem),
        radius: BorderRadius.circular(1.2.rem),
        border: Border.all(
          width: 1.px,
          color: Color(
            'color-mix(in srgb, var(--docs-shell-border-strong) 90%, transparent)',
          ),
        ),
        overflow: Overflow.hidden,
        backgroundColor: Color('var(--docs-shell-surface-elevated)'),
        raw: {
          'backface-visibility': 'hidden',
          'box-shadow':
              '0 24px 60px color-mix(in srgb, var(--docs-shell-shadow) 95%, transparent), inset 0 1px 0 rgba(255, 255, 255, 0.32)',
        },
      ),
      css('.docs-home-doc-front').styles(
        raw: {
          'background':
              'linear-gradient(160deg, color-mix(in srgb, var(--docs-shell-surface-elevated) 88%, white) 0%, color-mix(in srgb, var(--docs-shell-surface-soft) 92%, var(--docs-shell-accent-soft)) 100%)',
        },
      ),
      css('.docs-home-doc-back').styles(
        raw: {
          'transform': 'rotateY(180deg)',
          'background':
              'linear-gradient(160deg, color-mix(in srgb, var(--docs-shell-surface-elevated) 90%, white) 0%, color-mix(in srgb, var(--docs-shell-callout-bg) 72%, var(--docs-shell-surface-soft)) 100%)',
        },
      ),
      css('.docs-home-doc-header').styles(
        display: Display.flex,
        gap: Gap.column(0.32.rem),
        margin: Margin.only(bottom: 1.rem),
        padding: Padding.only(bottom: 0.7.rem),
        border: Border.only(
          bottom: BorderSide(
            width: 1.px,
            color: Color('var(--docs-shell-border)'),
          ),
        ),
      ),
      css('.docs-home-doc-dot').styles(
        width: 0.52.rem,
        height: 0.52.rem,
        radius: BorderRadius.circular(999.px),
        opacity: 0.88,
      ),
      css(
        '.docs-home-doc-dot.is-danger',
      ).styles(backgroundColor: const Color('#ff6b6b')),
      css(
        '.docs-home-doc-dot.is-warning',
      ).styles(backgroundColor: const Color('#ffd166')),
      css(
        '.docs-home-doc-dot.is-success',
      ).styles(backgroundColor: const Color('#22c55e')),
      css('.docs-home-doc-body').styles(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        gap: Gap.all(0.55.rem),
        flex: Flex(grow: 1),
      ),
      css('.docs-home-doc-line').styles(
        height: 0.42.rem,
        radius: BorderRadius.circular(999.px),
        backgroundColor: Color(
          'color-mix(in srgb, var(--docs-shell-muted) 18%, transparent)',
        ),
      ),
      css('.docs-home-doc-line.is-keyword').styles(
        width: 34.percent,
        backgroundColor: Color(
          'color-mix(in srgb, var(--docs-shell-accent) 36%, transparent)',
        ),
      ),
      css('.docs-home-doc-line.is-type').styles(
        width: 56.percent,
        margin: Margin.only(left: 8.percent),
        backgroundColor: Color(
          'color-mix(in srgb, var(--docs-shell-accent-strong) 40%, transparent)',
        ),
      ),
      css('.docs-home-doc-line.is-function').styles(
        width: 44.percent,
        margin: Margin.only(left: 11.percent),
        backgroundColor: Color(
          'color-mix(in srgb, var(--docs-shell-accent) 28%, transparent)',
        ),
      ),
      css('.docs-home-doc-line.is-wide').styles(
        width: 74.percent,
        margin: Margin.only(left: 4.percent),
      ),
      css('.docs-home-doc-line.is-mid').styles(
        width: 62.percent,
        margin: Margin.only(left: 12.percent),
      ),
      css('.docs-home-doc-line.is-short').styles(
        width: 31.percent,
        margin: Margin.only(left: 9.percent),
      ),
      css('.docs-home-doc-line.is-long').styles(width: 84.percent),
      css('.docs-home-doc-badge').styles(
        position: Position.absolute(right: 0.9.rem, bottom: 0.9.rem),
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        padding: Padding.symmetric(horizontal: 0.55.rem, vertical: 0.25.rem),
        radius: BorderRadius.circular(999.px),
        fontSize: 0.68.rem,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.12.rem,
        textTransform: TextTransform.upperCase,
      ),
      css('.docs-home-doc-badge.is-api').styles(
        color: Color('var(--docs-shell-accent-strong)'),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
      ),
      css('.docs-home-doc-badge.is-guide').styles(
        color: const Color('#15803d'),
        backgroundColor: Color('var(--docs-shell-callout-bg)'),
        raw: {
          'border':
              '1px solid color-mix(in srgb, var(--docs-shell-callout-border) 70%, transparent)',
        },
      ),
      css('.docs-home-particle').styles(
        position: Position.absolute(),
        fontWeight: FontWeight.w700,
        color: Color(
          'color-mix(in srgb, var(--docs-shell-accent) 58%, transparent)',
        ),
        opacity: 0,
        pointerEvents: PointerEvents.none,
        raw: {
          'font-family': 'var(--content-code-font)',
          'animation': 'docs-home-particle-float 8s ease-in-out infinite',
        },
      ),
      css(
        '.docs-home-particle.p-one',
      ).styles(raw: {'top': '14%', 'right': '5%', 'animation-delay': '0s'}),
      css(
        '.docs-home-particle.p-two',
      ).styles(raw: {'bottom': '16%', 'left': '4%', 'animation-delay': '2s'}),
      css(
        '.docs-home-particle.p-three',
      ).styles(raw: {'top': '24%', 'left': '10%', 'animation-delay': '4s'}),
      css(
        '.docs-home-particle.p-four',
      ).styles(raw: {'right': '9%', 'bottom': '10%', 'animation-delay': '6s'}),
      downContent([
        css('&').styles(
          gap: Gap.all(2.rem),
          raw: {'grid-template-columns': 'minmax(0, 1fr)'},
        ),
        css('.docs-home-hero-copy').styles(alignItems: AlignItems.center),
        css(
          '.docs-home-hero-name',
        ).styles(fontSize: 3.1.rem, textAlign: TextAlign.center),
        css('.docs-home-hero-text').styles(textAlign: TextAlign.center),
        css('.docs-home-hero-tagline').styles(textAlign: TextAlign.center),
        css(
          '.docs-home-hero-actions',
        ).styles(justifyContent: JustifyContent.center),
        css('.docs-home-hero-scene').styles(height: 18.rem),
      ]),
      downMobile([
        css('.docs-home-hero-name').styles(fontSize: 2.5.rem),
        css('.docs-home-hero-text').styles(fontSize: 1.12.rem),
        css('.docs-home-hero-tagline').styles(fontSize: 0.98.rem),
        css('.docs-home-doc').styles(width: 11.6.rem, height: 15.rem),
        css('.docs-home-hero-scene').styles(height: 15.5.rem),
      ]),
      downCompact([
        css(
          '.docs-home-hero-actions',
        ).styles(width: 100.percent, raw: {'justify-content': 'stretch'}),
        css(
          '.docs-home-hero-action',
        ).styles(width: 100.percent, raw: {'justify-content': 'center'}),
        css('.docs-home-particle').styles(display: Display.none),
      ]),
    ]),
    css.media(MediaQuery.raw('(prefers-reduced-motion: reduce)'), [
      css('.docs-home-hero::before').styles(raw: {'animation': 'none'}),
      css('.docs-home-doc').styles(raw: {'animation': 'none'}),
      css(
        '.docs-home-particle',
      ).styles(display: Display.none, opacity: 0, raw: {'animation': 'none'}),
      css('.docs-home-hero-action').styles(raw: {'transition': 'none'}),
    ]),
  ];
}
