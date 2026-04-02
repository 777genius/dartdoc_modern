import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsSidebarToggleRuntime extends StatelessComponent {
  const DocsSidebarToggleRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'hidden': 'hidden',
          'data-docs-sidebar-toggle-runtime': '',
        },
        const [],
      );
}
