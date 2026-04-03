import 'package:jaspr_content/src/page.dart';
import 'package:jaspr_content/src/page_extension/page_extension.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';

import '../docs_base.dart';

class BasePathLinkExtension implements PageExtension {
  const BasePathLinkExtension();

  @override
  Future<List<Node>> apply(Page page, List<Node> nodes) async {
    return _rewriteNodes(nodes, currentPageUrl: page.url);
  }

  List<Node> _rewriteNodes(List<Node> nodes, {required String currentPageUrl}) {
    return [
      for (final node in nodes) _rewriteNode(node, currentPageUrl: currentPageUrl),
    ];
  }

  Node _rewriteNode(Node node, {required String currentPageUrl}) {
    if (node is! ElementNode) return node;

    final rewrittenChildren = _rewriteNodes(
      node.children ?? const <Node>[],
      currentPageUrl: currentPageUrl,
    );
    if (node.tag != 'a') {
      return ElementNode(node.tag, node.attributes, rewrittenChildren);
    }

    final href = node.attributes['href'];
    if (href == null || href.isEmpty) {
      return ElementNode(node.tag, node.attributes, rewrittenChildren);
    }

    final rewrittenHref = _rewriteHref(href, currentPageUrl: currentPageUrl);
    final shouldEnableClientNav =
        !_isExternalHref(rewrittenHref) &&
        !rewrittenHref.startsWith('#') &&
        node.attributes['target'] != '_blank' &&
        !node.attributes.containsKey('download');

    return ElementNode('a', {
      ...node.attributes,
      'href': rewrittenHref,
      if (shouldEnableClientNav) 'data-docs-nav-link': 'true',
    }, rewrittenChildren);
  }

  String _rewriteHref(String href, {required String currentPageUrl}) {
    if (_isExternalHref(href)) return href;
    if (href.startsWith('#')) return '$currentPageUrl$href';
    if (!href.startsWith('/')) return href;
    return withDocsBasePath(href);
  }

  bool _isExternalHref(String href) {
    return href.startsWith('http://') ||
        href.startsWith('https://') ||
        href.startsWith('mailto:') ||
        href.startsWith('tel:');
  }
}
