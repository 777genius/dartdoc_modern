import 'package:jaspr/dom.dart';

import '../theme/docs_responsive.dart';

List<StyleRule> docsSidebarToggleStyles() => [
  css('.sidebar-toggle-button').styles(
    display: Display.none,
    justifyContent: JustifyContent.center,
    alignItems: AlignItems.center,
    width: 2.rem,
    height: 2.rem,
    backgroundColor: Colors.transparent,
    border: Border.none,
    color: Color('inherit'),
    cursor: Cursor.pointer,
    radius: BorderRadius.circular(0.6.rem),
  ),
  css(
    '.sidebar-toggle-button:hover',
  ).styles(backgroundColor: Color('#0000000d')),
  css('.sidebar-toggle-button:focus-visible').styles(
    outline: Outline(
      width: OutlineWidth(3.px),
      style: OutlineStyle.solid,
      color: Color('var(--docs-shell-focus)'),
      offset: 2.px,
    ),
  ),
  downContent([
    css(
      '[data-has-sidebar] .sidebar-toggle-button',
    ).styles(
      display: Display.flex,
      margin: Margin.only(left: (-0.85).rem),
    ),
  ]),
];

const docsSidebarToggleMenuIcon = '''
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" x2="20" y1="12" y2="12"></line><line x1="4" x2="20" y1="6" y2="6"></line><line x1="4" x2="20" y1="18" y2="18"></line></svg>
''';
