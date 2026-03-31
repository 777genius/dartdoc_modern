import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

class DartPadComponent extends CustomComponent {
  DartPadComponent() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(
      tag: 'pre',
      attributes: final preAttributes,
      children: [
        ElementNode(
          tag: 'code',
          attributes: final codeAttributes,
          children: final children,
        ),
      ],
    )) {
      final language = codeAttributes['class'];
      if (language != 'language-dartpad') return null;

      final source = children?.map((child) => child.innerText).join('') ?? '';
      final metadata = _parseMetadata(preAttributes['data-metadata'] ?? '');
      final mode = metadata['mode'] == 'flutter' ? 'flutter' : 'dart';
      final run = metadata['run'] != 'false';
      final height = int.tryParse(metadata['height'] ?? '') ?? 400;

      return _DartPadBlock(
        source: source,
        mode: mode,
        run: run,
        height: height,
      );
    }
    return null;
  }

  Map<String, String> _parseMetadata(String metadata) {
    final values = <String, String>{};
    for (final token in metadata.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final parts = token.split('=');
      if (parts.length == 2) {
        values[parts[0]] = parts[1];
      }
    }
    return values;
  }
}

class _DartPadBlock extends StatelessComponent {
  const _DartPadBlock({
    required this.source,
    required this.mode,
    required this.run,
    required this.height,
  });

  final String source;
  final String mode;
  final bool run;
  final int height;

  @override
  Component build(BuildContext context) {
    final encoded = base64Encode(utf8.encode(source));

    return div(
      classes: 'dartpad-wrapper',
      attributes: {
        'data-dartpad': '',
        'data-source-base64': encoded,
        'data-mode': mode,
        'data-run': '$run',
        'data-height': '$height',
      },
      [
        div(classes: 'dartpad-preview', [
          pre([
            code(
              attributes: {'class': 'language-dart'},
              [Component.text(source)],
            ),
          ]),
        ]),
        div(classes: 'dartpad-toolbar', [
          button(
            classes: 'dartpad-btn dartpad-run',
            attributes: {'type': 'button'},
            [Component.text('Run')],
          ),
          button(
            classes: 'dartpad-btn dartpad-copy',
            attributes: {'type': 'button'},
            [Component.text('Copy')],
          ),
          a(
            href: 'https://dartpad.dev',
            target: Target.blank,
            attributes: {'rel': 'noopener'},
            classes: 'dartpad-btn dartpad-open',
            [Component.text('Open')],
          ),
        ]),
        div(classes: 'dartpad-stage', []),
      ],
    );
  }
}
