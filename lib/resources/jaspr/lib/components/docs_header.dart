import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'docs_nav_link.dart';
import 'docs_sidebar_toggle.dart';
import '../theme/docs_responsive.dart';

class DocsHeader extends StatelessComponent {
  const DocsHeader({
    required this.logo,
    required this.title,
    required this.homeHref,
    this.items = const [],
    super.key,
  });

  final String logo;
  final String title;
  final String homeHref;
  final List<Component> items;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      header(classes: 'header', [
        const DocsSidebarToggle(),
        DocsNavLink(
          to: homeHref,
          classes: 'header-title',
          children: [
            img(src: logo, alt: 'Logo'),
            span([Component.text(title)]),
          ],
        ),
        div(classes: 'header-content', [
          div(classes: 'header-items', items),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get _styles => [
        css('.header', [
          css('&').styles(
            height: Unit.auto,
            display: Display.flex,
            alignItems: AlignItems.center,
            gap: Gap.column(1.rem),
            padding: Padding.symmetric(horizontal: 1.rem, vertical: .25.rem),
            margin: Margin.symmetric(horizontal: Unit.auto),
            border: Border.only(
              bottom: BorderSide(color: Color('#0000000d'), width: 1.px),
            ),
            raw: {
              'min-height': 'var(--docs-shell-header-height)',
              'padding-inline': 'var(--docs-shell-header-inline-pad)',
            },
          ),
          css('.header-title', [
            css('&').styles(
              display: Display.inlineFlex,
              flex: Flex(grow: 1, shrink: 1, basis: 12.rem),
              alignItems: AlignItems.center,
              gap: Gap.column(.75.rem),
              minWidth: Unit.zero,
              raw: {
                'max-width': 'min(28rem, 100%)',
              },
            ),
            css('img').styles(height: 1.5.rem, width: Unit.auto),
            css('span').styles(
              fontWeight: FontWeight.w700,
              minWidth: Unit.zero,
              raw: {
                'line-height': '1.1',
                'letter-spacing': '-0.025em',
                'overflow': 'hidden',
                'text-overflow': 'ellipsis',
                'white-space': 'nowrap',
              },
            ),
            css('&:hover span').styles(
              color: Color('var(--docs-shell-accent)'),
            ),
            css('&:focus-visible').styles(
              outline: Outline(
                width: OutlineWidth(3.px),
                style: OutlineStyle.solid,
                color: Color('var(--docs-shell-focus)'),
                offset: 2.px,
              ),
              radius: BorderRadius.circular(0.95.rem),
            ),
          ]),
          css('.header-content', [
            css('&').styles(
              display: Display.flex,
              flex: Flex(grow: 1, shrink: 1),
              justifyContent: JustifyContent.end,
              alignItems: AlignItems.center,
              minWidth: Unit.zero,
            ),
          ]),
          css('.header-items', [
            css('&').styles(
              display: Display.flex,
              gap: Gap.column(0.65.rem),
              alignItems: AlignItems.center,
              minWidth: Unit.zero,
              raw: {'flex-wrap': 'nowrap'},
            ),
          ]),
          downMobile([
            css('&').styles(
              gap: Gap.column(0.6.rem),
              padding:
                  Padding.symmetric(horizontal: 0.9.rem, vertical: 0.25.rem),
            ),
            css('.header-title').styles(
              flex: Flex(grow: 1, shrink: 1, basis: 7.5.rem),
              gap: Gap.column(0.55.rem),
              raw: {
                'max-width': 'calc(100vw - 11rem)',
              },
            ),
            css('.header-title img').styles(height: 1.3.rem),
            css('.header-title span').styles(
              fontSize: 0.95.rem,
              raw: {
                'max-width': '100%',
              },
            ),
            css('.header-items').styles(
              gap: Gap.column(0.45.rem),
            ),
          ]),
          downCompact([
            css('&').styles(
              gap: Gap.column(0.45.rem),
              padding:
                  Padding.symmetric(horizontal: 0.72.rem, vertical: 0.18.rem),
            ),
            css('.header-title').styles(
              flex: Flex(grow: 1, shrink: 1, basis: 6.2.rem),
              gap: Gap.column(0.45.rem),
              raw: {
                'max-width': 'calc(100vw - 6.8rem)',
              },
            ),
            css('.header-title img').styles(height: 1.16.rem),
            css('.header-content').styles(
              raw: {
                'flex': '0 0 auto',
                'min-width': '0',
              },
            ),
            css('.header-title span').styles(
              fontSize: 0.8.rem,
              raw: {
                'letter-spacing': '-0.02em',
              },
            ),
            css('.header-items').styles(
              gap: Gap.column(0.35.rem),
              raw: {
                'flex': '0 0 auto',
              },
            ),
          ]),
        ]),
      ];
}
