import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';
import '../theme/docs_responsive.dart';

final class DocsSidebarGroup {
  const DocsSidebarGroup({required this.items, this.title});

  final String? title;
  final List<DocsSidebarItem> items;
}

final class DocsSidebarItem {
  const DocsSidebarItem({
    required this.text,
    this.items = const [],
    this.href,
    this.collapsed = false,
  });

  final String text;
  final String? href;
  final bool collapsed;
  final List<DocsSidebarItem> items;
}

class DocsSidebar extends StatelessComponent {
  const DocsSidebar({this.currentRoute, required this.groups, super.key});

  final String? currentRoute;
  final List<DocsSidebarGroup> groups;

  @override
  Component build(BuildContext context) {
    final activeRoute = _normalizeRoute(currentRoute ?? context.page.url);

    return Component.fragment([
      Document.head(children: [Style(styles: _styles)]),
      nav(classes: 'sidebar', attributes: {
        'id': 'docs-sidebar'
      }, [
        button(
          classes: 'sidebar-close',
          attributes: {
            'type': 'button',
            'data-docs-sidebar-close': 'true',
            'aria-label': 'Close navigation',
          },
          [Component.text('×')],
        ),
        div([
          for (final group in groups)
            div(
                classes: group.title == null
                    ? 'sidebar-group sidebar-group-libraries'
                    : 'sidebar-group',
                [
                  if (group.title case final title?)
                    h3([Component.text(title)]),
                  ul([
                    for (final item in group.items)
                      _buildItem(item, activeRoute, depth: 0),
                  ]),
                ]),
        ]),
      ]),
    ]);
  }

  Component _buildItem(
    DocsSidebarItem item,
    String activeRoute, {
    required int depth,
  }) {
    final routeMatches = _matchesRoute(item.href, activeRoute);
    final containsActive = _containsActive(item, activeRoute);
    final hasChildren = item.items.isNotEmpty;

    if (!hasChildren) {
      return li(
        classes: 'sidebar-leaf sidebar-depth-$depth',
        [
          DocsNavLink(
            to: item.href ?? '#',
            classes: routeMatches ? 'sidebar-link active' : 'sidebar-link',
            children: [Component.text(item.text)],
          ),
        ],
      );
    }

    final isOpen = containsActive || !item.collapsed;
    final triggerClasses = [
      'sidebar-trigger',
      if (containsActive) 'active-branch',
      if (routeMatches) 'active',
    ].join(' ');

    return li(
      classes: 'sidebar-section sidebar-depth-$depth',
      [
        details(
          classes: isOpen ? 'sidebar-details open' : 'sidebar-details',
          attributes: {
            if (isOpen) 'open': 'open',
          },
          [
            summary(
              classes: triggerClasses,
              [
                span(classes: 'sidebar-trigger-label', [
                  Component.text(item.text),
                ]),
                span(
                  classes: 'sidebar-trigger-chevron',
                  attributes: {'aria-hidden': 'true'},
                  [Component.text('›')],
                ),
              ],
            ),
            ul(
              classes: depth == 0 ? 'sidebar-sublist root-sublist' : 'sidebar-sublist',
              [
                for (final child in item.items)
                  _buildItem(child, activeRoute, depth: depth + 1),
              ],
            ),
          ],
        ),
      ],
    );
  }

  bool _containsActive(DocsSidebarItem item, String activeRoute) {
    if (_matchesRoute(item.href, activeRoute)) return true;
    for (final child in item.items) {
      if (_containsActive(child, activeRoute)) return true;
    }
    return false;
  }

  bool _matchesRoute(String? href, String activeRoute) {
    if (href == null || href.isEmpty || href == '#') return false;
    final normalizedHref = _normalizeRoute(href);
    if (normalizedHref == activeRoute) return true;
    if (normalizedHref == '/api' && activeRoute.startsWith('/api/')) return true;
    if (normalizedHref.startsWith('/guide/') && activeRoute == normalizedHref) {
      return true;
    }
    return false;
  }

  String _normalizeRoute(String route) {
    if (route.isEmpty) return '/';
    final withoutFragment = route.split('#').first.split('?').first;
    if (withoutFragment.length > 1 && withoutFragment.endsWith('/')) {
      return withoutFragment.substring(0, withoutFragment.length - 1);
    }
    return withoutFragment;
  }

  static List<StyleRule> get _styles => [
        css('.sidebar', [
          css('&').styles(
            position: Position.relative(),
            fontSize: 0.93.rem,
            lineHeight: 1.35.rem,
            padding: Padding.zero,
          ),
          downContent([
            css('&').styles(
              width: 100.percent,
              maxWidth: 88.vw,
              padding: Padding.only(
                left: 0.35.rem,
                right: 0.35.rem,
                bottom: 1.rem,
                top: 0.75.rem,
              ),
              raw: {
                'width': 'var(--docs-shell-drawer-width)',
              },
            ),
          ]),
          css('.sidebar-close', [
            css('&').styles(
              position: Position.absolute(top: 0.75.rem, right: 0.75.rem),
              width: 2.rem,
              height: 2.rem,
              fontSize: 1.3.rem,
              lineHeight: 1.rem,
              backgroundColor: Color('#00000008'),
              border: Border.all(width: 1.px, color: Color('#00000014')),
              radius: BorderRadius.circular(999.px),
              cursor: Cursor.pointer,
              color: ContentColors.text,
            ),
            css('&').styles(display: Display.none),
            downContent([
              css('&').styles(display: Display.block),
            ]),
          ]),
          css('.sidebar-group', [
            css('&').styles(
              padding: Padding.only(top: 1.05.rem, right: 0.2.rem),
            ),
            css('h3').styles(
              fontWeight: FontWeight.w800,
              fontSize: 0.92.rem,
              padding: Padding.zero,
              margin: Margin.only(bottom: 0.65.rem, top: Unit.zero),
              color: ContentColors.text,
            ),
            css('ul').styles(
              listStyle: ListStyle.none,
              margin: Margin.zero,
              padding: Padding.zero,
            ),
            css('li').styles(margin: Margin.only(bottom: 0.08.rem)),
            css('.sidebar-section').styles(margin: Margin.only(bottom: 0.15.rem)),
            css('.sidebar-details').styles(
              raw: {
                'display': 'block',
              },
            ),
            css('.sidebar-details > summary').styles(
              listStyle: ListStyle.none,
              cursor: Cursor.pointer,
            ),
            css('.sidebar-details > summary::-webkit-details-marker').styles(
              display: Display.none,
            ),
            css('.sidebar-trigger').styles(
              display: Display.flex,
              justifyContent: JustifyContent.start,
              alignItems: AlignItems.center,
              gap: Gap.column(0.4.rem),
              padding:
                  Padding.symmetric(vertical: 0.48.rem, horizontal: Unit.zero),
              color: ContentColors.text,
              fontWeight: FontWeight.w600,
              transition: Transition(
                'color, opacity',
                duration: 150.ms,
                curve: Curve.easeInOut,
              ),
              raw: {
                'user-select': 'none',
              },
            ),
            css('.sidebar-trigger:hover').styles(
              color: ContentColors.primary,
            ),
            css('.sidebar-trigger-label').styles(
              raw: {
                'min-width': '0',
              },
            ),
            css('.sidebar-trigger-chevron').styles(
              display: Display.inlineBlock,
              opacity: 0.72,
              transition: Transition(
                'transform, opacity',
                duration: 150.ms,
                curve: Curve.easeInOut,
              ),
              raw: {
                'line-height': '1',
                'transform': 'rotate(90deg)',
              },
            ),
            css('.sidebar-details[open] > .sidebar-trigger .sidebar-trigger-chevron')
                .styles(
              opacity: 1,
              raw: {
                'transform': 'rotate(270deg)',
              },
            ),
            css('.sidebar-trigger.active-branch').styles(
              color: ContentColors.primary,
            ),
            css('.sidebar-sublist').styles(
              padding: Padding.only(left: 0.95.rem),
              margin: Margin.only(left: 0.15.rem, bottom: 0.15.rem),
              border: Border.only(
                left: BorderSide(
                  width: 1.px,
                  color: Color('var(--docs-shell-border)'),
                ),
              ),
            ),
            css('.sidebar-sublist.root-sublist').styles(
              margin: Margin.only(left: 0.1.rem),
            ),
            css('.sidebar-link').styles(
              opacity: 0.92,
              display: Display.block,
              margin: Margin.zero,
              padding:
                  Padding.symmetric(vertical: 0.45.rem, horizontal: Unit.zero),
              overflow: Overflow.hidden,
              radius: BorderRadius.circular(Unit.zero),
              color: ContentColors.text,
              transition: Transition(
                'color, opacity',
                duration: 150.ms,
                curve: Curve.easeInOut,
              ),
              raw: {
                'line-height': '1.35',
                'white-space': 'normal',
              },
            ),
            css('.sidebar-link:hover').styles(
              opacity: 1,
              color: ContentColors.primary,
            ),
            css('.sidebar-link.active').styles(
              opacity: 1,
              color: ContentColors.primary,
              fontWeight: FontWeight.w700,
              backgroundColor: Color('transparent'),
              shadow: BoxShadow.unset,
            ),
            css('.sidebar-depth-1 > .sidebar-link').styles(
              fontSize: 0.95.rem,
            ),
            css('.sidebar-depth-2 > .sidebar-link').styles(
              fontSize: 0.92.rem,
              opacity: 0.9,
            ),
            css('.sidebar-group-libraries').styles(
              margin: Margin.only(top: 0.2.rem),
            ),
            css('.sidebar-group-libraries .sidebar-link').styles(
              fontSize: 0.94.rem,
              opacity: 0.86,
              padding:
                  Padding.symmetric(vertical: 0.46.rem, horizontal: Unit.zero),
            ),
            css('.sidebar-group-libraries .sidebar-link.active').styles(
              opacity: 1,
            ),
          ]),
        ]),
      ];
}
