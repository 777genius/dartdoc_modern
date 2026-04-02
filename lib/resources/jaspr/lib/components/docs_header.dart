import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';
import 'docs_sidebar_toggle.dart';
import '../theme/docs_responsive.dart';

class DocsHeader extends StatelessComponent {
  const DocsHeader({
    required this.logo,
    required this.title,
    required this.homeHref,
    this.currentRoute,
    this.navItems = const [],
    this.items = const [],
    super.key,
  });

  final String logo;
  final String title;
  final String homeHref;
  final String? currentRoute;
  final List<DocsHeaderNavItem> navItems;
  final List<Component> items;

  @override
  Component build(BuildContext context) {
    final activeRoute = _normalizeRoute(currentRoute ?? homeHref);

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
          if (navItems.isNotEmpty)
            nav(classes: 'header-nav', [
              for (final item in navItems)
                DocsNavLink(
                  to: item.href,
                  classes: _isNavActive(item, activeRoute)
                      ? 'header-nav-link active'
                      : 'header-nav-link',
                  children: [Component.text(item.text)],
                ),
            ]),
          div(classes: 'header-items', items),
        ]),
      ]),
    ]);
  }

  bool _isNavActive(DocsHeaderNavItem item, String activeRoute) {
    final href = _normalizeRoute(item.href);
    if (href == activeRoute) return true;
    if (item.matchPrefix != null && activeRoute.startsWith(item.matchPrefix!)) {
      return true;
    }
    return false;
  }

  String _normalizeRoute(String route) {
    final withoutFragment = route.split('#').first.split('?').first;
    if (withoutFragment.length > 1 && withoutFragment.endsWith('/')) {
      return withoutFragment.substring(0, withoutFragment.length - 1);
    }
    return withoutFragment.isEmpty ? '/' : withoutFragment;
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
        border: Border.unset,
        backgroundColor: Color('transparent'),
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
          raw: {'max-width': 'min(28rem, 100%)'},
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
        css('&:hover span').styles(color: Color('var(--docs-shell-accent)')),
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
          gap: Gap.column(1.rem),
          justifyContent: JustifyContent.end,
          alignItems: AlignItems.center,
          minWidth: Unit.zero,
        ),
      ]),
      css('.header-nav', [
        css('&').styles(
          display: Display.flex,
          alignItems: AlignItems.center,
          gap: Gap.column(0.35.rem),
          minWidth: Unit.zero,
          raw: {'overflow-x': 'auto'},
        ),
        css('&::-webkit-scrollbar').styles(display: Display.none),
      ]),
      css('.header-nav-link').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        padding: Padding.symmetric(vertical: 0.4.rem, horizontal: 0.7.rem),
        radius: BorderRadius.circular(0.8.rem),
        color: ContentColors.text,
        fontWeight: FontWeight.w600,
        transition: Transition(
          'color, background-color',
          duration: 150.ms,
          curve: Curve.easeInOut,
        ),
        raw: {'white-space': 'nowrap'},
      ),
      css('.header-nav-link:hover').styles(
        color: Color('var(--docs-shell-accent)'),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
      ),
      css('.header-nav-link.active').styles(
        color: Color('var(--docs-shell-accent)'),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
      ),
      css('.header-repo-link').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        padding: Padding.symmetric(vertical: 0.42.rem, horizontal: 0.72.rem),
        radius: BorderRadius.circular(0.8.rem),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        color: ContentColors.text,
        fontWeight: FontWeight.w600,
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        transition: Transition(
          'color, background-color, border-color',
          duration: 150.ms,
          curve: Curve.easeInOut,
        ),
        raw: {'white-space': 'nowrap'},
      ),
      css('.header-repo-link:hover').styles(
        color: Color('var(--docs-shell-accent)'),
        backgroundColor: Color('var(--docs-shell-accent-soft)'),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border-strong)'),
        ),
      ),
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
          padding: Padding.symmetric(horizontal: 0.9.rem, vertical: 0.25.rem),
        ),
        css('.header-title').styles(
          flex: Flex(grow: 1, shrink: 1, basis: 7.5.rem),
          gap: Gap.column(0.55.rem),
          raw: {'max-width': 'calc(100vw - 11rem)'},
        ),
        css('.header-title img').styles(height: 1.3.rem),
        css(
          '.header-title span',
        ).styles(fontSize: 0.95.rem, raw: {'max-width': '100%'}),
        css('.header-items').styles(gap: Gap.column(0.45.rem)),
        css('.header-nav').styles(display: Display.none),
      ]),
      downCompact([
        css('&').styles(
          gap: Gap.column(0.45.rem),
          padding: Padding.symmetric(horizontal: 0.72.rem, vertical: 0.18.rem),
        ),
        css('.header-title').styles(
          flex: Flex(grow: 1, shrink: 1, basis: 6.2.rem),
          gap: Gap.column(0.45.rem),
          raw: {'max-width': 'calc(100vw - 6.8rem)'},
        ),
        css('.header-title img').styles(height: 1.16.rem),
        css(
          '.header-content',
        ).styles(raw: {'flex': '0 0 auto', 'min-width': '0'}),
        css(
          '.header-title span',
        ).styles(fontSize: 0.8.rem, raw: {'letter-spacing': '-0.02em'}),
        css(
          '.header-items',
        ).styles(gap: Gap.column(0.35.rem), raw: {'flex': '0 0 auto'}),
        css('.header-nav').styles(display: Display.none),
      ]),
    ]),
  ];
}

final class DocsHeaderNavItem {
  const DocsHeaderNavItem({
    required this.text,
    required this.href,
    this.matchPrefix,
  });

  final String text;
  final String href;
  final String? matchPrefix;
}
