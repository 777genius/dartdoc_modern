import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';
import '../theme/docs_responsive.dart';

final class DocsSidebarGroup {
  const DocsSidebarGroup({this.title, required this.items});

  final String? title;
  final List<DocsSidebarItem> items;
}

final class DocsSidebarItem {
  const DocsSidebarItem({required this.text, required this.href});

  final String text;
  final String href;
}

class DocsSidebar extends StatelessComponent {
  const DocsSidebar({this.currentRoute, required this.groups, super.key});

  final String? currentRoute;
  final List<DocsSidebarGroup> groups;

  @override
  Component build(BuildContext context) {
    final activeRoute = currentRoute ?? context.page.url;

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
                      li([
                        DocsNavLink(
                          to: item.href,
                          classes: activeRoute == item.href
                              ? 'sidebar-link active'
                              : 'sidebar-link',
                          children: [Component.text(item.text)],
                        ),
                      ]),
                  ]),
                ]),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get _styles => [
        css('.sidebar', [
          css('&').styles(
            position: Position.relative(),
            fontSize: 0.875.rem,
            lineHeight: 1.25.rem,
            padding:
                Padding.only(left: 0.5.rem, bottom: 1.25.rem, top: 0.75.rem),
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
          css('&').styles(padding: Padding.only(top: Unit.zero)),
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
              padding: Padding.only(top: 1.5.rem, right: 0.75.rem),
            ),
            css('h3').styles(
              fontWeight: FontWeight.w800,
              fontSize: 0.74.rem,
              padding: Padding.only(left: 0.75.rem),
              margin: Margin.only(bottom: 1.rem, top: Unit.zero),
              color: Color('var(--docs-shell-muted)'),
              textTransform: TextTransform.upperCase,
              raw: {'letter-spacing': '0.12em'},
            ),
            css('ul').styles(
              listStyle: ListStyle.none,
              margin: Margin.zero,
              padding: Padding.zero,
            ),
            css('li').styles(margin: Margin.only(bottom: 0.24.rem)),
            css('.sidebar-link').styles(
              opacity: 0.92,
              display: Display.block,
              margin: Margin.symmetric(horizontal: 0.18.rem),
              padding:
                  Padding.symmetric(vertical: 0.72.rem, horizontal: 0.92.rem),
              overflow: Overflow.hidden,
              radius: BorderRadius.circular(0.9.rem),
              color: ContentColors.text,
              transition: Transition(
                'background-color, color, transform, box-shadow',
                duration: 150.ms,
                curve: Curve.easeInOut,
              ),
              raw: {
                'position': 'relative',
                'line-height': '1.35',
                'display': '-webkit-box',
                '-webkit-box-orient': 'vertical',
                '-webkit-line-clamp': '2',
                'white-space': 'normal',
                'text-wrap': 'pretty',
              },
            ),
            css('.sidebar-link:hover').styles(
              opacity: 1,
              backgroundColor: Color('#0000000d'),
              raw: {'transform': 'translateX(2px)'},
            ),
            css('.sidebar-link.active').styles(
              opacity: 1,
              color: ContentColors.primary,
              fontWeight: FontWeight.w700,
              backgroundColor: Color(
                'color-mix(in srgb, currentColor 15%, transparent)',
              ),
              shadow: BoxShadow(
                offsetX: Unit.zero,
                offsetY: 10.px,
                blur: 16.px,
                color: Color('var(--docs-shell-shadow)'),
              ),
              raw: {
                'box-shadow':
                    'inset 4px 0 0 currentColor, 0 10px 16px var(--docs-shell-shadow)',
              },
            ),
            css('.sidebar-group-libraries').styles(
              margin: Margin.only(top: 0.6.rem),
            ),
            css('.sidebar-group-libraries .sidebar-link').styles(
              fontSize: 0.94.rem,
              opacity: 0.86,
              padding:
                  Padding.symmetric(vertical: 0.64.rem, horizontal: 0.92.rem),
            ),
            css('.sidebar-group-libraries .sidebar-link.active').styles(
              opacity: 1,
            ),
          ]),
        ]),
      ];
}
