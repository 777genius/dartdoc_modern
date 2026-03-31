import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsTocRuntime extends StatelessComponent {
  const DocsTocRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'data-docs-toc-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );
}
