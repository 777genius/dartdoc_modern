import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

class MermaidDiagramComponent extends CustomComponent {
  MermaidDiagramComponent() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(
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
        attributes: {'data-source-base64': encoded},
        [
          pre([
            code([Component.text(source)]),
          ]),
        ],
      );
    }
    return null;
  }
}
