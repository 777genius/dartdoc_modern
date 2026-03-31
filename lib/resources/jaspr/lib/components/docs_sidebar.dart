import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'docs_nav_link.dart';

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
            div(classes: 'sidebar-group', [
              if (group.title case final title?) h3([Component.text(title)]),
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
          css.media(MediaQuery.all(maxWidth: 1023.px), [
            css('&').styles(
              width: 18.5.rem,
              maxWidth: 88.vw,
              padding: Padding.only(
                left: 0.35.rem,
                right: 0.35.rem,
                bottom: 1.rem,
                top: 0.75.rem,
              ),
            ),
          ]),
          css.media(MediaQuery.all(minWidth: 1024.px), [
            css('&').styles(padding: Padding.only(top: Unit.zero)),
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
            css.media(MediaQuery.all(minWidth: 1024.px), [
              css('&').styles(display: Display.none),
            ]),
          ]),
          css('.sidebar-group', [
            css('&').styles(
              padding: Padding.only(top: 1.5.rem, right: 0.75.rem),
            ),
            css('h3').styles(
              fontWeight: FontWeight.w600,
              fontSize: 14.px,
              padding: Padding.only(left: 0.75.rem),
              margin: Margin.only(bottom: 1.rem, top: Unit.zero),
            ),
            css('ul').styles(
              listStyle: ListStyle.none,
              margin: Margin.zero,
              padding: Padding.zero,
            ),
            css('li').styles(margin: Margin.only(bottom: 0.18.rem)),
            css('.sidebar-link').styles(
              opacity: 0.92,
              display: Display.block,
              padding:
                  Padding.symmetric(vertical: 0.72.rem, horizontal: 0.92.rem),
              whiteSpace: WhiteSpace.noWrap,
              overflow: Overflow.hidden,
              textOverflow: TextOverflow.ellipsis,
              radius: BorderRadius.circular(0.9.rem),
              color: ContentColors.text,
              transition: Transition(
                'background-color, color, transform, box-shadow',
                duration: 150.ms,
                curve: Curve.easeInOut,
              ),
              raw: {
                'position': 'relative',
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
                offsetY: 12.px,
                blur: 24.px,
                color: Color('rgba(37, 99, 235, 0.14)'),
              ),
            ),
            css('.sidebar-link.active::before').styles(
              raw: {
                'content': '""',
                'position': 'absolute',
                'inset': '0 auto 0 0',
                'width': '0.28rem',
                'border-radius': '999px',
                'background': 'currentColor',
              },
            ),
          ]),
        ]),
      ];
}
