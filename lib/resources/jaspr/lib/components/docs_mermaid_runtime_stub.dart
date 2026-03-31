import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsMermaidRuntime extends StatelessComponent {
  const DocsMermaidRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'data-docs-mermaid-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );
}
