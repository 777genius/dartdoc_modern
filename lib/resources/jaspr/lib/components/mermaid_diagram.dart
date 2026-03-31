import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

class MermaidDiagramComponent extends CustomComponent {
  MermaidDiagramComponent() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node
        case ElementNode(
          tag: 'pre',
          children: [
            ElementNode(
              tag: 'code',
              attributes: final codeAttributes,
              children: final children,
            ),
          ],
        )) {
      if (codeAttributes['class'] != 'language-mermaid') return null;

      final source = children?.map((child) => child.innerText).join('') ?? '';
      final encoded = base64Encode(utf8.encode(source));

      return div(
        classes: 'mermaid-diagram',
        attributes: {
          'data-source-base64': encoded,
          'data-mermaid-state': 'pending',
        },
        [
          div(classes: 'mermaid-frame', [
            div(
              classes: 'mermaid-placeholder',
              attributes: {
                'data-mermaid-placeholder': '',
                'role': 'status',
                'aria-live': 'polite',
              },
              [
                span(classes: 'mermaid-placeholder-label', [
                  Component.text('Rendering Mermaid diagram'),
                ]),
              ],
            ),
            div(
              classes: 'mermaid-host mermaid',
              attributes: {
                'data-mermaid-host': '',
                'hidden': 'hidden',
                'aria-hidden': 'true',
              },
              const [],
            ),
            div(
              classes: 'mermaid-fallback',
              attributes: {
                'data-mermaid-fallback': '',
                'hidden': 'hidden',
              },
              [
                div(
                  classes: 'mermaid-fallback-message',
                  [
                    Component.text(
                        'Unable to render diagram. Showing Mermaid source instead.'),
                  ],
                ),
                pre([
                  code([Component.text(source)]),
                ]),
              ],
            ),
          ]),
        ],
      );
    }
    return null;
  }
}
