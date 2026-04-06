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
  static const _bashLanguages = {'bash', 'sh', 'shell'};

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

      var result = highlighting.docsHighlight.highlight(
        source,
        languageId: normalizedLanguage,
      );

      // Post-process bash blocks with richer token detection.
      if (_bashLanguages.contains(normalizedLanguage)) {
        _enhanceBashNodes(result.rootNode);
      }

      return _DocsCodeBlock(
        source: source,
        language: normalizedLanguage,
        highlighted: result,
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

// ---------------------------------------------------------------------------
// Bash post-processor (SSR side)
// ---------------------------------------------------------------------------

/// Scopes that should never be post-processed (already highlighted).
final _skipScopes = RegExp(
  r'comment|string|keyword|meta|number|literal|built_in',
);

/// Tokenizer matching operators, flags, line-continuation, and words.
final _bashToken = RegExp(
  r'(2>&1|>>|&&|\|\||[|;>]|--[a-zA-Z][a-zA-Z0-9_-]*'
  r'|\s-[a-zA-Z0-9]\b'
  r'|\\$'
  r'|[a-zA-Z_][a-zA-Z0-9_./-]*'
  r'|\n)',
);

const _operators = {'&&', '||', '|', ';', '>', '>>', '2>&1'};

/// Walks the highlight [node] tree and enriches unscoped text nodes with
/// command, flag, and operator scopes for bash code blocks.
void _enhanceBashNodes(highlighting.Node node) {
  _enhanceBashNodesRecursive(node, _BashState(cmdNext: true));
}

class _BashState {
  bool cmdNext;
  _BashState({required this.cmdNext});
}

void _enhanceBashNodesRecursive(highlighting.Node node, _BashState state,
    {bool? parentSkipped}) {
  final skip = parentSkipped ??
      (node.className != null && _skipScopes.hasMatch(node.className!));

  if (skip && node.value != null) return;

  // Leaf text node without a scope - candidate for enhancement.
  if (!skip && node.value != null && node.className == null) {
    final enhanced = _tokenizeBashText(node.value!, state);
    if (enhanced != null) {
      // Replace this leaf with children.
      node.value = null;
      node.children = enhanced;
      return;
    }
  }

  // Recurse into children (iterate on a copy since we may mutate the list).
  final children = List.of(node.children);
  for (var i = 0; i < children.length; i++) {
    _enhanceBashNodesRecursive(children[i], state, parentSkipped: skip);
  }
}

/// Tokenizes a plain text value into a list of [highlighting.Node]s with
/// appropriate className scopes, or returns `null` if no enhancement needed.
List<highlighting.Node>? _tokenizeBashText(String text, _BashState state) {
  final parts = <String>[];
  var last = 0;
  for (final m in _bashToken.allMatches(text)) {
    if (m.start > last) parts.add(text.substring(last, m.start));
    parts.add(m[0]!);
    last = m.end;
  }
  if (last < text.length) parts.add(text.substring(last));
  if (parts.length <= 1) return null;

  final nodes = <highlighting.Node>[];

  for (final t in parts) {
    if (t.isEmpty) continue;

    if (t == '\n') {
      state.cmdNext = true;
      nodes.add(highlighting.Node(value: t));
      continue;
    }
    if (t.trim().isEmpty) {
      nodes.add(highlighting.Node(value: t));
      continue;
    }

    String? cls;

    if (t.startsWith('--')) {
      cls = 'attribute';
      state.cmdNext = false;
    } else if (RegExp(r'^\s-[a-zA-Z0-9]$').hasMatch(t)) {
      // Short flag with leading whitespace: split into space + flag.
      nodes.add(highlighting.Node(value: t[0]));
      nodes.add(highlighting.Node(
        className: 'attribute',
        children: [highlighting.Node(value: t.substring(1))],
      ));
      state.cmdNext = false;
      continue;
    } else if (_operators.contains(t)) {
      cls = 'keyword';
      state.cmdNext = true;
    } else if (t == r'\') {
      cls = 'comment';
    } else if (state.cmdNext && RegExp(r'^[a-zA-Z_]').hasMatch(t)) {
      cls = 'built_in';
      state.cmdNext = false;
    } else {
      state.cmdNext = false;
    }

    if (cls != null) {
      nodes.add(highlighting.Node(
        className: cls,
        children: [highlighting.Node(value: t)],
      ));
    } else {
      nodes.add(highlighting.Node(value: t));
    }
  }

  return nodes;
}

// ---------------------------------------------------------------------------

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
