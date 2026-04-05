import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/theme.dart';

import '../docs_base.dart';
import '../project_version_routes.dart';
import 'docs_nav_link.dart';
import 'docs_sidebar_toggle.dart';
import '../theme/docs_responsive.dart';

class DocsHeader extends StatelessComponent {
  const DocsHeader({
    required this.logo,
    required this.title,
    required this.homeHref,
    this.currentRoute,
    this.jasprDocsUrl,
    this.vitePressDocsUrl,
    this.navItems = const [],
    this.items = const [],
    super.key,
  });

  final String logo;
  final String title;
  final String homeHref;
  final String? currentRoute;
  final String? jasprDocsUrl;
  final String? vitePressDocsUrl;
  final List<DocsHeaderNavItem> navItems;
  final List<Component> items;

  @override
  Component build(BuildContext context) {
    final activeRoute = _normalizeRoute(currentRoute ?? homeHref);
    final switchRoute = currentRoute ?? homeHref;

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
                  attributes: {
                    'data-docs-header-nav-link': 'true',
                    if (item.matchPrefix case final prefix?)
                      'data-docs-match-prefix': prefix,
                    if (item.additionalMatchPrefixes case final prefixes?
                        when prefixes.isNotEmpty)
                      'data-docs-match-prefixes': prefixes.join('|'),
                  },
                  children: [Component.text(item.text)],
                ),
            ]),
          div(classes: 'header-items', [
            if (jasprDocsUrl != null && vitePressDocsUrl != null)
              div(classes: 'version-switch', [
                DocsNavLink(
                  to: projectJasprUrlForRoute(switchRoute),
                  classes: 'version-switch-option is-active',
                  attributes: {'data-version': 'jaspr'},
                  children: [Component.text('Jaspr')],
                ),
                DocsNavLink(
                  to: projectVitePressUrlForRoute(switchRoute),
                  classes: 'version-switch-option',
                  attributes: {'data-version': 'vitepress'},
                  children: [Component.text('VitePress')],
                ),
              ]),
            ...items,
          ]),
        ]),
      ]),
    ]);
  }

  bool _isNavActive(DocsHeaderNavItem item, String activeRoute) {
    final href = _normalizeRoute(item.href);
    if (href == activeRoute) return true;
    if (item.matchPrefix case final prefix?) {
      final normalizedPrefix = _normalizeRoute(prefix);
      if (_matchesSectionPath(activeRoute, normalizedPrefix)) {
        return true;
      }
    }
    if (item.additionalMatchPrefixes case final prefixes?) {
      for (final prefix in prefixes) {
        final normalizedPrefix = _normalizeRoute(prefix);
        if (_matchesSectionPath(activeRoute, normalizedPrefix)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesSectionPath(String route, String prefix) {
    if (route == prefix) {
      return true;
    }
    if (prefix == '/') {
      return route == '/';
    }
    return route.startsWith('$prefix/');
  }

  String _normalizeRoute(String route) {
    final withoutFragment = route.split('#').first.split('?').first;
    final normalizedPath = stripDocsBasePath(withoutFragment);
    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      return normalizedPath.substring(0, normalizedPath.length - 1);
    }
    return normalizedPath.isEmpty ? '/' : normalizedPath;
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
        css(
          'img',
        ).styles(height: 2.25.rem, width: 2.25.rem, raw: {'flex': '0 0 auto'}),
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
        width: 2.6.rem,
        height: 2.6.rem,
        padding: Padding.zero,
        radius: BorderRadius.circular(999.px),
        border: Border.all(
          width: 1.px,
          color: Color('var(--docs-shell-border)'),
        ),
        color: ContentColors.text,
        backgroundColor: Color('var(--docs-shell-surface-soft)'),
        transition: Transition(
          'color, background-color, border-color',
          duration: 150.ms,
          curve: Curve.easeInOut,
        ),
      ),
      css('.header-repo-link-icon').styles(
        display: Display.inlineFlex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        raw: {'line-height': '1'},
      ),
      css(
        '.header-repo-link-icon svg',
      ).styles(width: 1.25.rem, height: 1.25.rem),
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
      downContent([
        css('&').styles(
          gap: Gap.column(0.72.rem),
          padding: Padding.symmetric(horizontal: 0.9.rem, vertical: 0.22.rem),
        ),
        css('.header-title').styles(
          flex: Flex(grow: 1, shrink: 1, basis: 7.8.rem),
          gap: Gap.column(0.65.rem),
          raw: {'max-width': 'calc(100vw - 14rem)'},
        ),
        css('.header-nav').styles(display: Display.none),
        css('.header-items').styles(gap: Gap.column(0.5.rem)),
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
        css('.header-title img').styles(height: 1.25.rem, width: 1.25.rem),
        css(
          '.header-title span',
        ).styles(fontSize: 0.95.rem, raw: {'max-width': '100%'}),
        css('.header-items').styles(gap: Gap.column(0.45.rem)),
        css('.header-repo-link').styles(width: 2.45.rem, height: 2.45.rem),
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
        css('.header-title img').styles(height: 1.1.rem, width: 1.1.rem),
        css(
          '.header-content',
        ).styles(raw: {'flex': '0 0 auto', 'min-width': '0'}),
        css(
          '.header-title span',
        ).styles(fontSize: 0.8.rem, raw: {'letter-spacing': '-0.02em'}),
        css(
          '.header-items',
        ).styles(gap: Gap.column(0.35.rem), raw: {'flex': '0 0 auto'}),
        css('.header-repo-link').styles(width: 2.3.rem, height: 2.3.rem),
        css(
          '.header-repo-link-icon svg',
        ).styles(width: 1.1.rem, height: 1.1.rem),
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
    this.additionalMatchPrefixes,
  });

  final String text;
  final String href;
  final String? matchPrefix;
  final List<String>? additionalMatchPrefixes;
}
