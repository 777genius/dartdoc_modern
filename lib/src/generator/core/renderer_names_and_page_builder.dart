part of 'api_markdown_renderer.dart';

// ---------------------------------------------------------------------------
// Generic name helpers (ADR-7).
// ---------------------------------------------------------------------------

/// Builds a plain-text name with generic type parameters.
///
/// Uses `tp.element.name!` for the type parameter name (NOT `tp.name` which
/// contains HTML) and `tp.boundType?.nameWithGenericsPlain` for the bound.
String plainNameWithGenerics(ModelElement element) {
  if (element is TypeParameters && element.typeParameters.isNotEmpty) {
    final params = element.typeParameters
        .map((tp) {
          var result = tp.element.name!;
          final bound = tp.boundType;
          if (bound != null) {
            result += ' extends ${bound.nameWithGenericsPlain}';
          }
          return result;
        })
        .join(', ');
    return '${element.name}<$params>';
  }
  return element.name;
}

/// Escapes markdown-sensitive punctuation for headings and inline text.
///
/// In code fences and inline code, escaping is NOT needed.
String escapeGenerics(String text) => text
    .replaceAll('<', r'\<')
    .replaceAll('>', r'\>')
    .replaceAll('[', r'\[')
    .replaceAll(']', r'\]');

// ---------------------------------------------------------------------------
// Testable string helpers.
// ---------------------------------------------------------------------------

/// Escapes pipe characters and angle brackets in table cell content.
///
/// Pipes are escaped to prevent breaking the markdown table structure.
/// Angle brackets are escaped to prevent VitePress/Vue from interpreting
/// generic type parameters (e.g. `List<E>`) as HTML component tags.
/// Content that is already escaped (backslash-prefixed `\<`, `\>`) or
/// wrapped in inline code backticks is left untouched.
@visibleForTesting
String escapeTableCell(String cell) {
  var result = cell.replaceAll('|', r'\|');
  // Escape angle brackets that are not already escaped and not inside
  // backtick-delimited inline code spans.
  if (result.contains('<')) {
    result = _escapeAngleBracketsInCell(result);
  }
  return result;
}

/// Escapes unescaped angle brackets in a table cell, preserving:
/// - Already-escaped sequences (`\<`, `\>`)
/// - Content inside backtick-delimited inline code spans
/// - Markdown link syntax `[text](url)`
/// - VitePress Badge components (`<Badge .../>`)
String _escapeAngleBracketsInCell(String text) {
  final buf = StringBuffer();
  final len = text.length;
  var i = 0;

  while (i < len) {
    final ch = text[i];

    // Skip inline code spans without escaping.
    if (ch == '`') {
      final codeEnd = text.indexOf('`', i + 1);
      if (codeEnd != -1) {
        buf.write(text.substring(i, codeEnd + 1));
        i = codeEnd + 1;
        continue;
      }
    }

    // Skip already-escaped angle brackets.
    if (ch == r'\' &&
        i + 1 < len &&
        (text[i + 1] == '<' || text[i + 1] == '>')) {
      buf.write(text.substring(i, i + 2));
      i += 2;
      continue;
    }

    if (ch == '<') {
      // Preserve VitePress Badge components: <Badge type="..." text="..." />
      if (text.substring(i).startsWith('<Badge ')) {
        final closeIndex = text.indexOf('/>', i);
        if (closeIndex != -1) {
          buf.write(text.substring(i, closeIndex + 2));
          i = closeIndex + 2;
          continue;
        }
      }
      // Escape the angle bracket.
      buf.write(r'\<');
      i++;
    } else if (ch == '>') {
      buf.write(r'\>');
      i++;
    } else {
      buf.write(ch);
      i++;
    }
  }

  return buf.toString();
}

String _normalizeSignatureHtml(String html) {
  final lines = html.replaceAll('\r\n', '\n').split('\n');
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines
      .where((line) => line.trim().isNotEmpty)
      .map(_normalizeSignatureLine)
      .join('\n');
}

String _normalizeSignatureLine(String line) {
  final fragment = parseFragment(line);
  final parts = <({String html, String text})>[];

  for (final node in fragment.nodes) {
    if (node is html.Text) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        parts.add((html: _htmlEsc(text), text: text));
      }
      continue;
    }

    if (node is html.Element) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) {
        parts.add((html: node.outerHtml, text: text));
      }
    }
  }

  if (parts.isEmpty) {
    return '';
  }

  final normalized = StringBuffer();
  var previousText = '';
  for (final part in parts) {
    if (_shouldInsertSignatureSpace(previousText, part.text)) {
      normalized.write('<span class="member-signature-space"> </span>');
    }
    normalized.write(
      '<span class="member-signature-token">${part.html}</span>',
    );
    previousText = part.text;
  }
  return normalized.toString();
}

bool _shouldInsertSignatureSpace(String previousText, String nextText) {
  if (previousText.isEmpty || nextText.isEmpty) return false;

  if (nextText == '<') {
    return previousText == 'operator';
  }

  if (nextText.startsWith('<') || nextText.startsWith('?')) {
    return false;
  }

  if (previousText == '.' || previousText == '?.' || previousText == '..') {
    return false;
  }

  if (nextText.startsWith('(') ||
      nextText.startsWith('[') ||
      RegExp(r'^[,.;:)\]}>]').hasMatch(nextText)) {
    return false;
  }

  if (RegExp(r'^(?:\(|\[|\{|<)$').hasMatch(previousText)) {
    return false;
  }

  return true;
}

/// Escapes characters that are special in YAML double-quoted string values.
@visibleForTesting
String yamlEscape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

// ---------------------------------------------------------------------------
// Helper: _MarkdownPageBuilder
// ---------------------------------------------------------------------------

/// A helper class for building VitePress markdown pages with proper
/// frontmatter, consistent formatting, and reusable section patterns.
class _MarkdownPageBuilder {
  final StringBuffer _buffer = StringBuffer();

  /// Writes the YAML frontmatter block.
  ///
  /// Every generated page disables `editLink`, `prev`, and `next` because
  /// these are auto-generated API pages. `lastUpdated` is inherited from
  /// the site config (enabled by default).
  void writeFrontmatter({
    required String title,
    required String description,
    required Object outline, // bool or List<int>
    String? category,
    String? library,
    String? sourceUrl,
    bool outlineCollapsible = false,
  }) {
    _buffer.writeln('---');
    // Frontmatter values are YAML strings, not Vue templates. VitePress
    // stores them as plain JavaScript strings in the page data bundle.
    // Raw `<>` from generic types (e.g. `List<E>`) are safe here because:
    // - SSR: @unhead/vue properly HTML-encodes values in <title> and <meta>
    // - SPA: document.title is set via JS (text property, not innerHTML)
    // Using HTML entities (`&lt;`) would show literal `&lt;` in browser tabs
    // during SPA navigation since JS text assignment doesn't decode entities.
    _buffer.writeln('title: "${yamlEscape(title)}"');
    _buffer.writeln('description: "${yamlEscape(description)}"');
    if (category != null) {
      _buffer.writeln('category: "${yamlEscape(category)}"');
    }
    if (library != null) {
      _buffer.writeln('library: "${yamlEscape(library)}"');
    }
    if (sourceUrl != null) {
      _buffer.writeln('sourceUrl: "${yamlEscape(sourceUrl)}"');
    }
    if (outline is bool) {
      _buffer.writeln('outline: $outline');
    } else if (outline is List<int>) {
      _buffer.writeln('outline: [${outline.join(', ')}]');
    }
    if (outlineCollapsible) {
      _buffer.writeln('outlineCollapsible: true');
    }
    _buffer.writeln('editLink: false');
    _buffer.writeln('prev: false');
    _buffer.writeln('next: false');
    _buffer.writeln('---');
    _buffer.writeln();
  }

  /// Writes a top-level heading (h1) with optional badges.
  void writeH1(
    String text, {
    bool deprecated = false,
    List<String> badges = const [],
  }) {
    final escaped = escapeGenerics(text);
    final buf = StringBuffer('# ');

    if (deprecated) {
      buf.write('<Badge type="warning" text="deprecated" /> ');
      buf.write('~~$escaped~~ ');
    } else {
      buf.write('$escaped ');
    }

    for (final badge in badges) {
      buf.write(badge);
      buf.write(' ');
    }

    _buffer.writeln(buf.toString().trimRight());
    _buffer.writeln();
  }

  /// Writes an h2 section heading with an explicit ID to prevent collisions
  /// with member-level anchors (e.g., `## Values` auto-generates `id="values"`
  /// which collides with an enum constant named `values`).
  void writeH2(String text) {
    final slug = text.toLowerCase().replaceAll(' ', '-');
    _buffer.writeln('## $text {#section-$slug}');
    _buffer.writeln();
  }

  /// Writes an h3 member heading with an anchor ID and optional badges.
  void writeH3WithAnchor(
    String text, {
    required String anchor,
    bool deprecated = false,
    List<String> badges = const [],
  }) {
    final escapedText = escapeGenerics(text);
    final buf = StringBuffer('### ');
    if (deprecated) {
      buf.write('<Badge type="warning" text="deprecated" /> ');
      buf.write('~~$escapedText~~');
    } else {
      buf.write(escapedText);
    }
    for (final badge in badges) {
      buf.write(' $badge');
    }
    buf.write(' {#$anchor}');
    _buffer.writeln(buf.toString());
    _buffer.writeln();
  }

  /// Writes a fenced code block (no escaping needed inside).
  void writeCodeBlock(String code, {String language = 'dart'}) {
    _buffer.writeln('```$language');
    _buffer.writeln(code);
    _buffer.writeln('```');
    _buffer.writeln();
  }

  /// Writes a member signature as raw HTML with clickable type links.
  void writeSignature(String htmlSignature) {
    final normalizedSignature = _normalizeSignatureHtml(htmlSignature);
    final renderedSignature = normalizedSignature
        .split('\n')
        .map((line) => '<span class="member-signature-line">$line</span>')
        .join();
    _buffer.writeln(
      '<div class="member-signature"><div class="member-signature-code" data-signature-normalized="true">$renderedSignature</div></div>',
    );
    _buffer.writeln();
  }

  /// Writes a deprecation warning container.
  ///
  /// The [message] is escaped for angle brackets to prevent VitePress/Vue
  /// from interpreting generic type parameters in deprecation messages
  /// (e.g. "Use `Foo<Bar>` instead") as HTML component tags.
  void writeDeprecationNotice(String message) {
    _buffer.writeln(':::warning DEPRECATED');
    if (message.isNotEmpty) {
      _buffer.writeln(escapeGenerics(message));
    }
    _buffer.writeln(':::');
    _buffer.writeln();
  }

  /// Writes an info container (blue) for reference sections like
  /// "Implementers", "Superclass Constraints", "Available Extensions".
  ///
  /// Items should be pre-escaped by callers (e.g. via [_markdownLink] or
  /// [escapeGenerics]). This method does NOT apply additional escaping
  /// because items may contain valid markdown links with intentional
  /// backslash-escaped generics.
  void writeInfoContainer(String title, List<String> items) {
    if (items.isEmpty) return;
    _buffer.writeln(':::info $title');
    for (final item in items) {
      _buffer.writeln('- $item');
    }
    _buffer.writeln(':::');
    _buffer.writeln();
  }

  /// Writes a tip container (green) for best practices and important notes.
  void writeTipContainer(String title, String content) {
    _buffer.writeln(':::tip $title');
    if (content.isNotEmpty) {
      _buffer.writeln(content);
    }
    _buffer.writeln(':::');
    _buffer.writeln();
  }

  /// Writes a collapsible details container for source code, parameters, etc.
  void writeDetailsContainer(String summary, String content) {
    _buffer.writeln(':::details $summary');
    if (content.isNotEmpty) {
      _buffer.writeln(content);
    }
    _buffer.writeln(':::');
    _buffer.writeln();
  }

  /// Writes a danger container (red) for breaking changes.
  void writeDangerContainer(String title, String content) {
    _buffer.writeln(':::danger $title');
    if (content.isNotEmpty) {
      _buffer.writeln(content);
    }
    _buffer.writeln(':::');
    _buffer.writeln();
  }

  /// Writes a paragraph of text.
  void writeParagraph(String text) {
    if (text.isNotEmpty) {
      _buffer.writeln(text);
      _buffer.writeln();
    }
  }

  /// Writes an "Inherited from" notice.
  ///
  /// The [className] is escaped for angle brackets to prevent VitePress/Vue
  /// from interpreting generic type parameters in class names as HTML
  /// component tags. While `element.enclosingElement.name` typically returns
  /// a bare name without generics, this provides defensive safety.
  void writeInheritedFrom(String className) {
    _buffer.writeln('*Inherited from ${escapeGenerics(className)}.*');
    _buffer.writeln();
  }

  /// Writes a markdown table with header and rows.
  void writeTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) return;
    final columnCount = effectiveTableColumnCount(headers, rows);
    final effectiveHeaders = headers.take(columnCount).toList(growable: false);
    final effectiveRows = rows
        .map(
          (row) => List.generate(
            columnCount,
            (index) => index < row.length ? row[index] : '',
            growable: false,
          ),
        )
        .toList(growable: false);

    _buffer.writeln('| ${effectiveHeaders.map(escapeTableCell).join(' | ')} |');
    _buffer.writeln('|${effectiveHeaders.map((_) => '---').join('|')}|');
    for (final row in effectiveRows) {
      _buffer.writeln('| ${row.map(escapeTableCell).join(' | ')} |');
    }
    _buffer.writeln();
  }

  /// Writes raw text without any processing.
  void writeRaw(String text) {
    _buffer.write(text);
  }

  @override
  String toString() => _buffer.toString();
}

/// Escapes special HTML characters in text for use inside HTML output.
String _htmlEsc(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Decodes common HTML entities back to plain text.
///
/// Source code from the dartdoc model may contain HTML entities (e.g.
/// `&lt;`, `&gt;`) from the analyzer's HTML-escape pipeline. These must
/// be decoded before embedding in markdown code fences.
String _htmlUnescape(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&#60;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&#62;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&#38;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#34;', '"')
    .replaceAll('&#39;', "'");

/// Drops trailing table columns that are empty across every row.
///
/// This keeps summary tables compact for sections like Constants or Typedefs
/// where dartdoc often has no one-line docs at all, avoiding an always-empty
/// Description column in both VitePress and Jaspr output.
@visibleForTesting
int effectiveTableColumnCount(List<String> headers, List<List<String>> rows) {
  var count = headers.length;
  while (count > 1) {
    final columnIndex = count - 1;
    final columnIsEmpty = rows.every(
      (row) => columnIndex >= row.length || row[columnIndex].trim().isEmpty,
    );
    if (!columnIsEmpty) {
      break;
    }
    count--;
  }
  return count;
}
