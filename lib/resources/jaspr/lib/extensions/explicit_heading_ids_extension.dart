import 'package:jaspr_content/src/page.dart';
import 'package:jaspr_content/src/page_extension/page_extension.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';

class ExplicitHeadingIdsExtension implements PageExtension {
  const ExplicitHeadingIdsExtension();

  static final _headingTag = RegExp(r'^h[1-6]$', caseSensitive: false);
  static final _explicitAnchor = RegExp(
    r'(?:\s+)?\{#([A-Za-z0-9:_\-.]+)\}\s*$',
  );

  @override
  Future<List<Node>> apply(Page page, List<Node> nodes) async {
    return [for (final node in nodes) _rewriteNode(node)];
  }

  Node _rewriteNode(Node node) {
    if (node is! ElementNode) return node;

    final rewrittenChildren = [
      for (final child in node.children ?? const <Node>[]) _rewriteNode(child),
    ];

    if (!_headingTag.hasMatch(node.tag)) {
      return ElementNode(node.tag, node.attributes, rewrittenChildren);
    }

    final explicitId = _extractTrailingAnchor(rewrittenChildren);
    if (explicitId == null) {
      return ElementNode(node.tag, node.attributes, rewrittenChildren);
    }

    return ElementNode(
      node.tag,
      {...node.attributes, 'id': explicitId},
      rewrittenChildren,
    );
  }

  String? _extractTrailingAnchor(List<Node> children) {
    for (var index = children.length - 1; index >= 0; index--) {
      final child = children[index];
      if (child is! TextNode || child.raw) continue;

      final match = _explicitAnchor.firstMatch(child.text);
      if (match == null) continue;

      final cleanedText = child.text.replaceFirst(_explicitAnchor, '');
      if (cleanedText.isEmpty) {
        children.removeAt(index);
      } else {
        children[index] = TextNode(cleanedText, raw: child.raw);
      }
      return match.group(1)!;
    }
    return null;
  }
}
