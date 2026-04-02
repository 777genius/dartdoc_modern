import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'docs_sidebar_toggle_shared.dart';

class DocsSidebarToggle extends StatelessComponent {
  const DocsSidebarToggle({super.key});

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(children: [Style(styles: docsSidebarToggleStyles())]),
      button(
        classes: 'sidebar-toggle-button',
        attributes: const {
          'type': 'button',
          'data-docs-sidebar-toggle': '',
          'aria-label': 'Open navigation menu',
          'aria-expanded': 'false',
          'aria-controls': 'docs-sidebar',
        },
        [RawText(docsSidebarToggleMenuIcon)],
      ),
    ]);
  }
}
