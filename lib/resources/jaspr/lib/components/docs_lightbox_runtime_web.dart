import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

@client
class DocsLightboxRuntime extends StatelessComponent {
  const DocsLightboxRuntime({super.key});

  @override
  Component build(BuildContext context) => span(
        attributes: {
          'hidden': 'hidden',
          'data-docs-lightbox-runtime': '',
        },
        const [],
      );
}
