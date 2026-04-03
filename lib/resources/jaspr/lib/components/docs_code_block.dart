import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/src/page_parser/page_parser.dart';
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart' hide Color;

/// Jaspr-safe replacement for `jaspr_content`'s default `CodeBlock`.
///
/// `syntax_highlight_lite` initializes only the Dart grammar by default.
/// Markdown fences like `none` or `text` should stay plain, while the most
/// common shell fences are highlighted by a small built-in lexer so static
/// generation remains deterministic.
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
  };

  static const _shellLanguages = {
    'console',
    'shell',
    'shellsession',
    'sh',
    'bash',
    'zsh',
  };

  static const _highlightedLanguages = {'dart'};

  bool _initialized = false;
  HighlighterTheme? _defaultTheme;

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

      if (!_initialized) {
        Highlighter.initialize(['dart']);
        _initialized = true;
      }

      if (normalizedLanguage == null) {
        return _DocsCodeBlock(source: source);
      }

      if (_shellLanguages.contains(normalizedLanguage)) {
        return _DocsCodeBlock(
          source: source,
          language: normalizedLanguage,
          shellTokens: _ShellSyntaxHighlighter.highlight(source),
        );
      }

      return AsyncBuilder(
        builder: (_) async {
          final highlighter = Highlighter(
            language: normalizedLanguage,
            theme: _defaultTheme ??= await HighlighterTheme.loadDarkTheme(),
          );
          return _DocsCodeBlock(
            source: source,
            highlighter: highlighter,
            language: normalizedLanguage,
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
    if (_shellLanguages.contains(normalized)) return normalized;
    if (_highlightedLanguages.contains(normalized)) return normalized;
    return null;
  }
}

class _DocsCodeBlock extends StatelessComponent {
  const _DocsCodeBlock({
    required this.source,
    this.highlighter,
    this.language,
    this.shellTokens,
  });

  final String source;
  final Highlighter? highlighter;
  final String? language;
  final List<_ShellToken>? shellTokens;

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
          attributes: {if (language != null) 'class': 'language-$language'},
          [
            if (highlighter != null)
              _buildSpan(highlighter!.highlight(source))
            else if (shellTokens != null)
              for (final token in shellTokens!) _buildShellToken(token)
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

  Component _buildShellToken(_ShellToken token) {
    final className = token.kind.className;
    if (className == null) {
      return Component.text(token.text);
    }

    return span(classes: 'code-token $className', [Component.text(token.text)]);
  }
}

enum _ShellTokenKind {
  plain(null),
  command('code-token-command'),
  option('code-token-option'),
  variable('code-token-variable'),
  string('code-token-string'),
  comment('code-token-comment'),
  operator('code-token-operator');

  const _ShellTokenKind(this.className);

  final String? className;
}

class _ShellToken {
  const _ShellToken(this.kind, this.text);

  final _ShellTokenKind kind;
  final String text;
}

final class _ShellSyntaxHighlighter {
  static const _commandBoundaryOperators = {'|', '||', '|&', '&&', ';', '&'};

  static final _wordPattern = RegExp(r'[A-Za-z0-9_./:@%+-]');
  static final _assignmentPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=');

  static List<_ShellToken> highlight(String source) {
    final tokens = <_ShellToken>[];
    var i = 0;
    var expectsCommand = true;

    while (i < source.length) {
      final char = source[i];

      if (char == '\n') {
        tokens.add(const _ShellToken(_ShellTokenKind.plain, '\n'));
        expectsCommand = true;
        i++;
        continue;
      }

      if (_isWhitespace(char)) {
        final start = i;
        while (i < source.length &&
            source[i] != '\n' &&
            _isWhitespace(source[i])) {
          i++;
        }
        tokens.add(
          _ShellToken(_ShellTokenKind.plain, source.substring(start, i)),
        );
        continue;
      }

      if (char == '#' && _startsComment(source, i)) {
        final start = i;
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        tokens.add(
          _ShellToken(_ShellTokenKind.comment, source.substring(start, i)),
        );
        continue;
      }

      if (char == '\'' || char == '"') {
        final quote = char;
        final start = i++;
        while (i < source.length) {
          final current = source[i];
          if (current == '\\' && quote == '"' && i + 1 < source.length) {
            i += 2;
            continue;
          }
          i++;
          if (current == quote) break;
        }
        tokens.add(
          _ShellToken(_ShellTokenKind.string, source.substring(start, i)),
        );
        expectsCommand = false;
        continue;
      }

      final operator = _readOperator(source, i);
      if (operator != null) {
        tokens.add(_ShellToken(_ShellTokenKind.operator, operator));
        expectsCommand = _commandBoundaryOperators.contains(operator);
        i += operator.length;
        continue;
      }

      if (char == r'$') {
        final start = i;
        i = _consumeVariable(source, i);
        tokens.add(
          _ShellToken(_ShellTokenKind.variable, source.substring(start, i)),
        );
        expectsCommand = false;
        continue;
      }

      if (_looksLikeAssignment(source, i)) {
        final start = i;
        while (i < source.length &&
            source[i] != '\n' &&
            !_isWhitespace(source[i]) &&
            _readOperator(source, i) == null) {
          i++;
        }
        final assignment = source.substring(start, i);
        final equalsIndex = assignment.indexOf('=');
        tokens.add(
          _ShellToken(
            _ShellTokenKind.variable,
            assignment.substring(0, equalsIndex),
          ),
        );
        tokens.add(const _ShellToken(_ShellTokenKind.operator, '='));
        if (equalsIndex + 1 < assignment.length) {
          tokens.add(
            _ShellToken(
              _ShellTokenKind.string,
              assignment.substring(equalsIndex + 1),
            ),
          );
        }
        expectsCommand = true;
        continue;
      }

      final start = i;
      while (i < source.length &&
          source[i] != '\n' &&
          !_isWhitespace(source[i]) &&
          _readOperator(source, i) == null) {
        if (source[i] == r'$') break;
        i++;
      }

      if (start == i) {
        tokens.add(_ShellToken(_ShellTokenKind.plain, source[i]));
        i++;
        continue;
      }

      final word = source.substring(start, i);
      final kind = expectsCommand && !word.startsWith('-')
          ? _ShellTokenKind.command
          : word.startsWith('-')
          ? _ShellTokenKind.option
          : _ShellTokenKind.plain;
      tokens.add(_ShellToken(kind, word));
      expectsCommand = false;
    }

    return tokens;
  }

  static bool _looksLikeAssignment(String source, int index) {
    final remainder = source.substring(index);
    return _assignmentPattern.hasMatch(remainder);
  }

  static int _consumeVariable(String source, int index) {
    if (index + 1 >= source.length) return index + 1;
    final next = source[index + 1];

    if (next == '{') {
      var cursor = index + 2;
      while (cursor < source.length && source[cursor] != '}') {
        cursor++;
      }
      return cursor < source.length ? cursor + 1 : cursor;
    }

    if (RegExp(r'[0-9@*#?$!_-]').hasMatch(next)) {
      return index + 2;
    }

    var cursor = index + 1;
    while (cursor < source.length && _wordPattern.hasMatch(source[cursor])) {
      cursor++;
    }
    return cursor;
  }

  static String? _readOperator(String source, int index) {
    for (final operator in const ['&&', '||', '|&', '>>', '<<']) {
      if (source.startsWith(operator, index)) return operator;
    }
    final char = source[index];
    if ('|;&()\\'.contains(char)) return char;
    return null;
  }

  static bool _startsComment(String source, int index) {
    if (index == 0) return true;
    final previous = source[index - 1];
    return previous == '\n' || _isWhitespace(previous);
  }

  static bool _isWhitespace(String char) => char == ' ' || char == '\t';
}
