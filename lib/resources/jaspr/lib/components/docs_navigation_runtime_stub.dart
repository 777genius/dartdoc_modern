import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsNavigationRuntime extends StatelessComponent {
  const DocsNavigationRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'hidden': 'hidden',
          'data-docs-nav-runtime': '',
        },
        const [],
      );
}
