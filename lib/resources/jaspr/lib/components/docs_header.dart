import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'docs_nav_link.dart';
import 'docs_sidebar_toggle.dart';

class DocsHeader extends StatelessComponent {
  const DocsHeader({
    required this.logo,
    required this.title,
    this.items = const [],
    super.key,
  });

  final String logo;
  final String title;
  final List<Component> items;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      header(classes: 'header', [
        const DocsSidebarToggle(),
        DocsNavLink(
          to: '/',
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
            height: 4.rem,
            display: Display.flex,
            alignItems: AlignItems.center,
            gap: Gap.column(1.rem),
            padding: Padding.symmetric(horizontal: 1.rem, vertical: .25.rem),
            margin: Margin.symmetric(horizontal: Unit.auto),
            border: Border.only(
              bottom: BorderSide(color: Color('#0000000d'), width: 1.px),
            ),
          ),
          css.media(MediaQuery.all(minWidth: 768.px), [
            css('&').styles(
              padding: Padding.symmetric(horizontal: 2.5.rem),
            ),
          ]),
          css('.header-title', [
            css('&').styles(
              display: Display.inlineFlex,
              flex: Flex(grow: 1, shrink: 1, basis: 12.rem),
              alignItems: AlignItems.center,
              gap: Gap.column(.75.rem),
              minWidth: Unit.zero,
            ),
            css('img').styles(height: 1.5.rem, width: Unit.auto),
            css('span').styles(
              fontWeight: FontWeight.w700,
              minWidth: Unit.zero,
              raw: {
                'overflow': 'hidden',
                'text-overflow': 'ellipsis',
                'white-space': 'nowrap',
              },
            ),
          ]),
          css('.header-content', [
            css('&').styles(
              display: Display.flex,
              flex: Flex(grow: 1, shrink: 1),
              justifyContent: JustifyContent.end,
              minWidth: Unit.zero,
            ),
          ]),
          css('.header-items', [
            css('&').styles(
              display: Display.flex,
              gap: Gap.column(0.25.rem),
              alignItems: AlignItems.center,
              minWidth: Unit.zero,
            ),
          ]),
          css.media(MediaQuery.all(maxWidth: 767.px), [
            css('&').styles(
              gap: Gap.column(0.6.rem),
              padding: Padding.symmetric(horizontal: 0.9.rem, vertical: 0.25.rem),
            ),
            css('.header-title').styles(
              gap: Gap.column(0.55.rem),
            ),
            css('.header-title img').styles(height: 1.3.rem),
            css('.header-title span').styles(
              fontSize: 0.95.rem,
            ),
          ]),
        ]),
      ];
}
