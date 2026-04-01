import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart' hide Color;

/// Jaspr-safe replacement for `jaspr_content`'s default `CodeBlock`.
///
/// `syntax_highlight_lite` initializes only the Dart grammar by default.
/// Markdown fences like `none`, `text`, or `bash` therefore crash static
/// generation if they are passed through as highlight languages.
class DocsCodeBlock extends CustomComponent {
  DocsCodeBlock({this.defaultLanguage = 'dart'}) : super.base();

  final String defaultLanguage;

  static const _plainLanguages = {
    '',
    'none',
    'text',
    'txt',
    'plain',
    'plaintext',
    'console',
    'shell',
    'sh',
    'bash',
  };

  static const _highlightedLanguages = {
    'dart',
  };

  bool _initialized = false;
  HighlighterTheme? _defaultTheme;

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node
        case ElementNode(tag: 'Code' || 'CodeBlock', :final children, :final attributes) ||
            ElementNode(
              tag: 'pre',
              children: [ElementNode(tag: 'code', :final children, :final attributes)],
            )) {
      final rawLanguage = _extractLanguage(attributes);
      final language = _normalizeLanguage(rawLanguage);
      final source = children?.map((child) => child.innerText).join(' ') ?? '';

      if (!_initialized) {
        Highlighter.initialize(['dart']);
        _initialized = true;
      }

      if (language == null) {
        return _DocsCodeBlock(source: source);
      }

      return AsyncBuilder(
        builder: (_) async {
          final highlighter = Highlighter(
            language: language,
            theme: _defaultTheme ??= await HighlighterTheme.loadDarkTheme(),
          );
          return _DocsCodeBlock(
            source: source,
            highlighter: highlighter,
            language: language,
          );
        },
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
    if (_highlightedLanguages.contains(normalized)) return normalized;
    return null;
  }
}

class _DocsCodeBlock extends StatelessComponent {
  const _DocsCodeBlock({
    required this.source,
    this.highlighter,
    this.language,
  });

  final String source;
  final Highlighter? highlighter;
  final String? language;

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
            if (language != null) 'class': 'language-$language',
          },
          [
            if (highlighter != null)
              _buildSpan(highlighter!.highlight(source))
            else
              Component.text(source),
          ],
        ),
      ]),
    ]);
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
