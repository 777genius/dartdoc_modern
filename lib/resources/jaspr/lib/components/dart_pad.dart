import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart' hide Color;

class DartPadComponent extends CustomComponent {
  DartPadComponent() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node
        case ElementNode(
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

  static bool _highlighterInitialized = false;
  static HighlighterTheme? _darkTheme;

  @override
  Component build(BuildContext context) {
    final encoded = base64Encode(utf8.encode(source));

    if (!_highlighterInitialized) {
      Highlighter.initialize(['dart']);
      _highlighterInitialized = true;
    }

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
          AsyncBuilder(
            builder: (_) async {
              final highlighter = Highlighter(
                language: 'dart',
                theme: _darkTheme ??= await HighlighterTheme.loadDarkTheme(),
              );

              return pre([
                code(
                  attributes: {'class': 'language-dart'},
                  [_buildSpan(highlighter.highlight(source))],
                ),
              ]);
            },
          ),
        ]),
        div(classes: 'dartpad-toolbar', [
          button(
            classes: 'dartpad-btn dartpad-run',
            attributes: {'type': 'button'},
            [
              span(classes: 'dartpad-btn-icon', [Component.text('▶')]),
              span(classes: 'dartpad-btn-label', [Component.text('Run')]),
            ],
          ),
          button(
            classes: 'dartpad-btn dartpad-copy',
            attributes: {'type': 'button'},
            [
              span(classes: 'dartpad-btn-icon', [Component.text('⧉')]),
              span(classes: 'dartpad-btn-label', [Component.text('Copy')]),
            ],
          ),
          a(
            href: 'https://dartpad.dev',
            target: Target.blank,
            attributes: {'rel': 'noopener'},
            classes: 'dartpad-btn dartpad-open',
            [
              span(classes: 'dartpad-btn-icon', [Component.text('↗')]),
              span(classes: 'dartpad-btn-label', [Component.text('Open')]),
            ],
          ),
        ]),
        div(classes: 'dartpad-stage', []),
      ],
    );
  }

  Component _buildSpan(TextSpan textSpan) {
    Styles? styles;

    if (textSpan.style case final style?) {
      styles = Styles(
        color: Color.value(style.foreground.argb & 0x00FFFFFF),
        fontWeight: style.bold ? FontWeight.bold : null,
        fontStyle: style.italic ? FontStyle.italic : null,
        textDecoration: style.underline
            ? TextDecoration(line: TextDecorationLine.underline)
            : null,
      );
    }

    if (styles == null && textSpan.children.isEmpty) {
      return Component.text(textSpan.text ?? '');
    }

    return span(styles: styles, [
      if (textSpan.text != null) Component.text(textSpan.text!),
      for (final child in textSpan.children) _buildSpan(child),
    ]);
  }
}
