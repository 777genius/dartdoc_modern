import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class DocsDisclosureRuntime extends StatelessComponent {
  const DocsDisclosureRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'data-docs-disclosure-runtime': '',
          'hidden': 'hidden',
          'aria-hidden': 'true',
        },
        const [],
      );
}
