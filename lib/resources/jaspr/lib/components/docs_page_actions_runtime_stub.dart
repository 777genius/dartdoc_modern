import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsPageActionsRuntime extends StatelessComponent {
  const DocsPageActionsRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
    attributes: {'hidden': 'hidden', 'data-docs-page-actions-runtime': ''},
    const [],
  );
}
