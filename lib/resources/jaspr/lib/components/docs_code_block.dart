import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';

import '../vendor/highlighting/highlighting.dart' as highlighting;

/// Jaspr-safe replacement for `jaspr_content`'s default `CodeBlock`.
///
/// Uses a vendored multi-language highlighter so static generation remains
/// deterministic while supporting common documentation fence languages.
class DocsCodeBlock extends CustomComponent {
  DocsCodeBlock({this.defaultLanguage = 'dart'}) : super.base();

  final String defaultLanguage;

  static const _plainLanguages = {'', 'none', 'text', 'txt', 'plain'};

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node
        case ElementNode(
              tag: 'Code' || 'CodeBlock',
              :final children,
              :final attributes,
            ) ||
            ElementNode(
              tag: 'pre',
              children: [
                ElementNode(tag: 'code', :final children, :final attributes),
              ],
            )) {
      final rawLanguage = _extractLanguage(attributes);
      final normalizedLanguage = _normalizeLanguage(rawLanguage);
      final source = children?.map((child) => child.innerText).join(' ') ?? '';

      if (normalizedLanguage == null) {
        return _DocsCodeBlock(source: source);
      }

      return _DocsCodeBlock(
        source: source,
        language: normalizedLanguage,
        highlighted: highlighting.docsHighlight.highlight(
          source,
          languageId: normalizedLanguage,
        ),
      );
    }

    return null;
  }

  String? _extractLanguage(Map<String, String> attributes) {
    var language = attributes['language'];
    final cssClass = attributes['class'];
    if (language == null && (cssClass?.startsWith('language-') ?? false)) {
      language = cssClass!.substring('language-'.length);
    }
    return language;
  }

  String? _normalizeLanguage(String? language) {
    final normalized = language?.trim().toLowerCase() ?? '';
    if (_plainLanguages.contains(normalized)) return null;
    return highlighting.docsHighlight.canonicalize(normalized);
  }
}

class _DocsCodeBlock extends StatelessComponent {
  const _DocsCodeBlock({required this.source, this.language, this.highlighted});

  final String source;
  final String? language;
  final highlighting.Result? highlighted;

  @override
  Component build(BuildContext context) {
    return div(classes: 'code-block', [
      button(
        classes: 'code-block-copy-button',
        attributes: {
          'type': 'button',
          'aria-label': 'Copy code',
          'data-docs-copy': source,
        },
        [Component.text('⧉')],
      ),
      pre([
        code(
          attributes: {
            if (language != null) 'class': 'hljs language-$language',
          },
          [
            if (highlighted != null)
              _buildHighlightedNode(highlighted!.rootNode, isRoot: true)
            else
              Component.text(source),
          ],
        ),
      ]),
    ]);
  }

  Component _buildHighlightedNode(
    highlighting.Node node, {
    bool isRoot = false,
  }) {
    if (node.value case final String text?) {
      return Component.text(text);
    }

    final children = [
      for (final child in node.children) _buildHighlightedNode(child),
    ];

    if (isRoot) {
      return span(children);
    }

    final classes = <String>[];
    if (node.sublanguage == true && node.language != null) {
      classes.add('language-${node.language}');
    } else if (node.className case final String className?) {
      classes.addAll(
        highlighting.docsHighlight
            .scopeToCssClasses(className)
            .split(' ')
            .where((value) => value.isNotEmpty),
      );
    }

    if (classes.isEmpty) {
      return span(children);
    }

    return span(classes: classes.join(' '), children);
  }
}
