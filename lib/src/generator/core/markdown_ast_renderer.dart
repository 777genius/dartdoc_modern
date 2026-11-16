part of 'markdown_docs.dart';

/// Serializes a markdown AST (list of [md.Node]s) back to markdown text.
///
/// This renderer walks the AST produced by the `markdown` package's parser
/// and produces clean markdown output. It handles all common markdown
/// constructs including headings, paragraphs, emphasis, links, code blocks,
/// lists, blockquotes, and tables.
///
/// **Important:** The `markdown` v7 package uses only [md.Element] (with a
/// `tag` string property) and [md.Text] nodes. There are NO named classes
/// like `Emph`, `Strong`, or `Link`.
class MarkdownRenderer implements md.NodeVisitor {
  final StringBuffer _buffer = StringBuffer();

  /// Tracks the number of consecutive trailing newline characters in [_buffer].
  ///
  /// This avoids calling `_buffer.toString()` (which copies the entire buffer)
  /// just to check whether the buffer ends with `\n` or `\n\n`. Updated by
  /// [_writeToBuffer] and [_writelnToBuffer].
  int _trailingNewlines = 0;

  /// Stack of elements currently being visited, used for context-dependent
  /// rendering (e.g., detecting `<pre><code>` for fenced code blocks).
  final List<md.Element> _elementStack = [];

  /// Tracks the current ordered list index for proper numbering.
  /// Uses a stack to support nested ordered lists without overwriting
  /// the parent counter.
  final List<int> _orderedListStack = [];

  /// Tracks the current nesting depth of lists (ul and ol).
  /// Used to compute indentation for nested list items and code blocks.
  int _listDepth = 0;

  /// Tracks the current nesting depth of blockquotes.
  /// Used to compute the correct `> ` prefix for nested blockquotes.
  int _blockquoteDepth = 0;

  /// Whether we are currently inside a `<pre><code>` block (fenced code).
  /// Content inside should NOT be escaped.
  bool _inCodeBlock = false;

  /// Whether we are currently inside an inline `<code>` element.
  /// Content inside should NOT be escaped.
  bool _inInlineCode = false;

  /// Whether we are currently inside an `<a>` element (link).
  /// Link text is already escaped by [MarkdownDocProcessor._escapeLinkText],
  /// so [_escapeAngleBrackets] must NOT be called again to avoid
  /// double-escaping (`\<` → `\&lt;`).
  bool _inLink = false;

  /// Whether we are currently inside a GitHub-style markdown alert block
  /// (`<div class="markdown-alert-*">`), which needs to be converted to
  /// VitePress `:::type` container syntax.
  bool _inAlert = false;

  /// Whether the alert title paragraph has already been skipped.
  /// Reset to `false` when entering a new alert block.
  bool _alertTitleSkipped = false;

  /// Collects table rows during table rendering.
  final List<List<String>> _tableRows = [];

  /// Collects cells for the current table row.
  List<String>? _currentRowCells;

  /// Buffer for collecting cell content during table rendering.
  StringBuffer? _cellBuffer;

  /// Collects header alignments for table separator rendering.
  final List<String?> _tableAlignments = [];

  /// Renders a list of AST [nodes] to markdown text.
  String render(List<md.Node> nodes) {
    for (final node in nodes) {
      node.accept(this);
    }
    return _buffer.toString().trimRight();
  }

  /// Matches HTML-like tags: opening (`<tag ...>`), closing (`</tag>`),
  /// or self-closing (`<tag ... />`).
  static final _htmlTagPattern = RegExp(
    r'<(/?[a-zA-Z][a-zA-Z0-9]*(?:-[a-zA-Z0-9]+)*)\b([^>]*)(/?)>',
  );

  /// Escapes angle brackets in [content] using a whitelist-based approach.
  ///
  /// The method scans character by character and for each `<`:
  /// 1. **First** checks if it matches an HTML tag via [_htmlTagPattern].
  ///    - If the tag is in [_safeHtmlTags] → pass through as raw HTML.
  ///    - If the tag is NOT in the safe list → escape via `\<...\>`.
  /// 2. If not an HTML tag, but `<` is followed by a letter or digit →
  ///    treat as a generic type parameter. Uses bracket-counting to find
  ///    the matching `>` and escapes all `<>` inside with backslashes.
  /// 3. Otherwise → bare `<`, passed through as-is.
  ///
  /// Content inside backtick-delimited inline code is left untouched.
  static String _escapeAngleBrackets(String content) {
    final buf = StringBuffer();
    final len = content.length;
    var i = 0;

    while (i < len) {
      final ch = content[i];

      // Skip inline code spans (backtick-delimited) without escaping.
      if (ch == '`') {
        final codeEnd = content.indexOf('`', i + 1);
        if (codeEnd != -1) {
          buf.write(content.substring(i, codeEnd + 1));
          i = codeEnd + 1;
          continue;
        }
      }

      if (ch == '<') {
        // Step 1: Check if this `<` starts an HTML-like tag.
        final tagMatch = _htmlTagPattern.matchAsPrefix(content, i);
        if (tagMatch != null) {
          // Extract the tag name, stripping leading `/` for closing tags.
          final rawTag = tagMatch[1]!;
          final tagName = rawTag.startsWith('/') ? rawTag.substring(1) : rawTag;
          if (_safeHtmlTags.contains(tagName.toLowerCase())) {
            final isClosing = rawTag.startsWith('/');
            final isSelfClosing =
                tagMatch[3] == '/' ||
                _voidHtmlTags.contains(tagName.toLowerCase());
            // Vue components (PascalCase like <Badge>) always pass through.
            final isVueComponent =
                tagName.isNotEmpty &&
                tagName[0] == tagName[0].toUpperCase() &&
                tagName[0] != tagName[0].toLowerCase();
            if (isSelfClosing || isVueComponent) {
              // Self-closing/void tags and Vue components always pass through.
              buf.write(tagMatch[0]!);
            } else if (isClosing) {
              // Closing tag: only pass through if there's a matching opening
              // tag earlier in the SAME text content. Without this check,
              // orphaned closing tags (split into separate text nodes by the
              // markdown parser) produce "Invalid end tag" errors in Vue.
              final openTag = '<${tagName.toLowerCase()}';
              final before = content.substring(0, i).toLowerCase();
              if (before.contains(openTag)) {
                buf.write(tagMatch[0]!);
              } else {
                final inner = content.substring(i + 1, tagMatch.end - 1);
                buf.write('\\<$inner\\>');
              }
            } else {
              // Opening tag: only pass through if there's a matching
              // closing tag in the remaining content. Without this check,
              // inline mentions like "the <div> tag" would create orphaned
              // HTML elements that break Vue's template compiler.
              final closingTag = '</${tagName.toLowerCase()}>';
              final remaining = content.substring(tagMatch.end).toLowerCase();
              if (remaining.contains(closingTag)) {
                buf.write(tagMatch[0]!);
              } else {
                final inner = content.substring(i + 1, tagMatch.end - 1);
                buf.write('\\<$inner\\>');
              }
            }
          } else {
            // Unsafe/unknown HTML tag — escape with backslashes.
            final inner = content.substring(i + 1, tagMatch.end - 1);
            buf.write('\\<$inner\\>');
          }
          i = tagMatch.end;
          continue;
        }

        // Step 2: Not an HTML tag. Check if `<` is followed by a letter
        // or digit, indicating a generic type parameter context
        // (e.g. `Future<void>`, `List<int>`, `Map<String, dynamic>`,
        // `an <Event>` in prose).
        if (i + 1 < len && _isLetterOrDigit(content.codeUnitAt(i + 1))) {
          // Use bracket-counting to find the matching `>`.
          buf.write(r'\<');
          i++;
          var depth = 1;
          while (i < len && depth > 0) {
            final c = content[i];
            if (c == '<') {
              depth++;
              buf.write(r'\<');
              i++;
            } else if (c == '>') {
              depth--;
              buf.write(r'\>');
              i++;
            } else {
              buf.write(c);
              i++;
            }
          }
          continue;
        }

        // Step 3: Bare `<` (e.g. `a < b`, math) — pass through as-is.
        buf.write(ch);
        i++;
      } else {
        buf.write(ch);
        i++;
      }
    }

    return buf.toString();
  }

  /// Returns `true` if [code] is an ASCII letter (A-Z, a-z) or digit (0-9).
  static bool _isLetterOrDigit(int code) =>
      (code >= 0x41 && code <= 0x5A) || // A-Z
      (code >= 0x61 && code <= 0x7A) || // a-z
      (code >= 0x30 && code <= 0x39); // 0-9

  @override
  void visitText(md.Text text) {
    var content = text.textContent;

    // Escape angle brackets in non-code contexts.
    //
    // VitePress compiles markdown as Vue SFCs, so ANY raw HTML tag in
    // the markdown output triggers Vue's template compiler. Doc comments
    // often contain HTML tags as examples (e.g. `<menu>`, `<template>`,
    // `<video>`), which cause compile errors.
    //
    // Generic type parameters (like `Future<Map<String, dynamic>>`) are
    // escaped with backslashes (`\<...\>`) for correct VitePress rendering.
    // HTML-like tags (like `<div>`) are escaped with entities (`&lt;...&gt;`).
    // Intentional HTML from `{@inject-html}` is handled separately via
    // DARTDOC_INJECT markers that bypass this escaping.
    //
    // Code blocks and inline code are exempt (rendered verbatim).
    if (!_inCodeBlock && !_inInlineCode && !_inLink && content.contains('<')) {
      content = _escapeAngleBrackets(content);
    }

    if (_cellBuffer != null) {
      _cellBuffer!.write(content);
      return;
    }
    _writeToBuffer(content);
  }

  @override
  bool visitElementBefore(md.Element element) {
    _elementStack.add(element);

    switch (element.tag) {
      // Block-level elements: headings
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _ensureBlankLine();
        final level = int.parse(element.tag.substring(1));
        _writeToBuffer('${'#' * level} ');
        return true;

      case 'p':
        // Inside an alert block, the first <p> contains the alert title
        // (e.g. "Note", "Warning"). VitePress generates this automatically,
        // so we skip it.
        if (_inAlert && !_alertTitleSkipped) {
          _alertTitleSkipped = true;
          return false; // Skip the title paragraph and its children.
        }
        if (_isInsideBlockquote()) {
          // Paragraphs inside blockquotes: prefix with `> ` if not the first.
          if (_isNotFirstChild(element)) {
            _writelnToBuffer();
            _writeToBuffer('> ' * _blockquoteDepth);
          }
        } else if (_isInsideListItem()) {
          // Paragraphs inside list items: separate with blank line if not first.
          if (_isNotFirstChild(element)) {
            _writelnToBuffer();
          }
        } else {
          _ensureBlankLine();
        }
        return true;

      case 'blockquote':
        _blockquoteDepth++;
        _ensureBlankLine();
        _writeToBuffer('> ' * _blockquoteDepth);
        return true;

      case 'pre':
        _ensureBlankLine();
        // Check if this is a fenced code block (pre > code).
        if (_hasSingleCodeChild(element)) {
          _inCodeBlock = true;
          final codeChild = element.children!.first as md.Element;
          final language = _extractLanguage(codeChild);
          final codeIndent = _listDepth > 0 ? '  ' * _listDepth : '';
          final fence = _computeFence(codeChild);
          _writelnToBuffer('$codeIndent$fence$language');
          _renderCodeBlockContent(codeChild, indent: codeIndent);
          _writelnToBuffer();
          _writeToBuffer('$codeIndent$fence');
          _inCodeBlock = false;
          return false; // Don't visit children -- we already handled them.
        }
        // Non-code pre block -- just pass through content.
        return true;

      case 'code':
        if (_inCodeBlock) {
          // Already handled by the `pre` case above.
          return true;
        }
        _inInlineCode = true;
        _writeToTarget('`');
        return true;

      case 'em':
        _writeToTarget('*');
        return true;

      case 'strong':
        _writeToTarget('**');
        return true;

      case 'del':
        _writeToTarget('~~');
        return true;

      case 'a':
        // Links: `[text](href)`
        // Only suppress angle bracket escaping for resolved bracket
        // references (marked with `data-resolved` by _resolveLinkReference).
        // Explicit markdown links like `[<intent-filter>](url)` still need
        // escaping in their link text.
        _inLink = element.attributes.containsKey('data-resolved');
        _writeToTarget('[');
        return true;

      case 'img':
        // Images: `![alt](src)`
        final alt = element.attributes['alt'] ?? '';
        final src = element.attributes['src'] ?? '';
        final title = element.attributes['title'];
        if (title != null) {
          _writeToTarget('![$alt]($src "$title")');
        } else {
          _writeToTarget('![$alt]($src)');
        }
        return false; // Self-closing, no children.

      case 'br':
        _writeToTarget('  \n');
        return false;

      case 'hr':
        _ensureBlankLine();
        _writeToBuffer('---');
        return false;

      case 'ul':
        if (!_isInsideListItem()) {
          _ensureBlankLine();
        }
        _listDepth++;
        return true;

      case 'ol':
        _orderedListStack.add(0);
        if (!_isInsideListItem()) {
          _ensureBlankLine();
        }
        _listDepth++;
        return true;

      case 'li':
        final indent = '  ' * (_listDepth - 1);
        final parentTag = _parentTag();
        if (parentTag == 'ol') {
          _orderedListStack.last++;
          _writeToBuffer('$indent${_orderedListStack.last}. ');
        } else {
          _writeToBuffer('$indent- ');
        }
        return true;

      // Table elements
      case 'table':
        _tableRows.clear();
        _tableAlignments.clear();
        _ensureBlankLine();
        return true;

      case 'thead' || 'tbody':
        return true;

      case 'tr':
        _currentRowCells = [];
        return true;

      case 'th' || 'td':
        _cellBuffer = StringBuffer();
        // Track alignment from header cells.
        if (element.tag == 'th') {
          _tableAlignments.add(element.attributes['style']);
        }
        return true;

      case 'div':
        final classAttr = element.attributes['class'] ?? '';
        if (classAttr.contains('markdown-alert')) {
          _ensureBlankLine();
          final typeMatch = RegExp(
            r'markdown-alert-(\w+)',
          ).firstMatch(classAttr);
          final alertType = typeMatch?.group(1) ?? 'note';
          const typeMap = {
            'note': 'info',
            'tip': 'tip',
            'important': 'info',
            'caution': 'warning',
            'warning': 'danger',
          };
          final vpType = typeMap[alertType] ?? 'info';
          _writelnToBuffer(':::$vpType');
          _inAlert = true;
          _alertTitleSkipped = false;
          return true;
        }
        // Fall through to default safe HTML tag handling.
        _writeToTarget(_openTag(element));
        return true;

      default:
        if (_isSafeHtmlTag(element.tag)) {
          // Known-safe HTML elements -- pass through as HTML.
          _writeToTarget(_openTag(element));
        } else {
          // Unsafe tags (e.g. <menu>, <video>, <template>, <x-foo>):
          // escape to prevent Vue template compiler errors.
          _writeToTarget(_escapedOpenTag(element));
        }
        return true;
    }
  }

  @override
  void visitElementAfter(md.Element element) {
    _elementStack.removeLast();

    switch (element.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        // Add generated ID as custom heading ID if present.
        if (element.generatedId != null) {
          _writeToBuffer(' {#${element.generatedId}}');
        }
        _writelnToBuffer();

      case 'p':
        if (_isInsideBlockquote()) {
          _writelnToBuffer();
        } else if (_isInsideListItem()) {
          _writelnToBuffer();
        } else {
          _writelnToBuffer();
          _writelnToBuffer();
        }

      case 'blockquote':
        _blockquoteDepth--;
        // Ensure trailing newline after blockquote.
        if (_trailingNewlines < 1) {
          _writelnToBuffer();
        }

      case 'code':
        if (!_inCodeBlock) {
          _inInlineCode = false;
          _writeToTarget('`');
        }

      case 'em':
        _writeToTarget('*');

      case 'strong':
        _writeToTarget('**');

      case 'del':
        _writeToTarget('~~');

      case 'a':
        _inLink = false;
        final href = element.attributes['href'] ?? '';
        final title = element.attributes['title'];
        if (title != null) {
          _writeToTarget(']($href "$title")');
        } else {
          _writeToTarget(']($href)');
        }

      case 'li':
        if (_trailingNewlines < 1) {
          _writelnToBuffer();
        }

      case 'ul':
        _listDepth--;

      case 'ol':
        _listDepth--;
        _orderedListStack.removeLast();

      case 'tr':
        if (_currentRowCells != null) {
          _tableRows.add(_currentRowCells!);
          _currentRowCells = null;
        }

      case 'th' || 'td':
        if (_cellBuffer != null && _currentRowCells != null) {
          _currentRowCells!.add(_cellBuffer!.toString().trim());
          _cellBuffer = null;
        }

      case 'table':
        _renderTable();

      case 'thead' || 'tbody':
        break;

      case 'div':
        if (_inAlert) {
          _writelnToBuffer(':::');
          _ensureBlankLine();
          _inAlert = false;
          return;
        }
        // Close regular div tags.
        if (element.children != null) {
          _writeToTarget('</div>');
          if (_cellBuffer == null) {
            _writelnToBuffer();
          }
        }

      default:
        if (_isSafeHtmlTag(element.tag)) {
          // Close known-safe HTML tags.
          if (element.children != null) {
            _writeToTarget('</${element.tag}>');
            if (_cellBuffer == null && _isBlockLevelTag(element.tag)) {
              _writelnToBuffer();
            }
          }
        } else {
          // Close escaped unsafe tags.
          if (element.children != null) {
            _writeToTarget('&lt;/${element.tag}&gt;');
          }
        }
    }
  }

  /// Block-level HTML tags that need newline separation in markdown output.
  static const _blockLevelTags = {
    'div',
    'section',
    'article',
    'aside',
    'header',
    'footer',
    'nav',
    'main',
    'figure',
    'figcaption',
    'details',
    'summary',
    'dialog',
    'address',
  };

  /// HTML tags safe to pass through in VitePress markdown output.
  ///
  /// Any tag NOT in this set is escaped to `&lt;tag&gt;` to prevent
  /// Vue's template compiler from interpreting it as an HTML element.
  /// This is needed because doc comments sometimes contain HTML tags as
  /// examples (e.g. `<menu>`, `<video>`, `<template>`) that are not
  /// meant to be rendered as actual HTML.
  static const _safeHtmlTags = {
    // Block containers
    'div', 'section', 'article', 'aside', 'header', 'footer',
    'nav', 'main', 'figure', 'figcaption', 'details', 'summary',
    'address', 'dialog',
    // Text formatting
    'span', 'em', 'strong', 'b', 'i', 'u', 's', 'del', 'ins',
    'mark', 'sub', 'sup', 'small', 'abbr', 'cite', 'q', 'dfn',
    'kbd', 'var', 'samp', 'time',
    // Block text
    'p', 'blockquote',
    // Links and media
    'a', 'img', 'iframe', 'picture', 'source', 'video', 'audio',
    // Lists
    'ul', 'ol', 'li', 'dl', 'dt', 'dd',
    // Tables
    'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td',
    'caption', 'colgroup', 'col',
    // Code
    'pre', 'code',
    // Line
    'br', 'hr', 'wbr',
    // Headings
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  };

  /// HTML void elements (self-closing, never have content or closing tags).
  static const _voidHtmlTags = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  /// Whether [tag] is safe to pass through as raw HTML in VitePress.
  static bool _isSafeHtmlTag(String tag) =>
      _safeHtmlTags.contains(tag.toLowerCase());

  /// Whether [tag] is a block-level HTML element.
  static bool _isBlockLevelTag(String tag) =>
      _blockLevelTags.contains(tag.toLowerCase());

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------

  /// Writes [text] to the main buffer and updates [_trailingNewlines].
  ///
  /// All writes to [_buffer] should go through this method (or
  /// [_writelnToBuffer]) so that the trailing-newline counter stays in sync.
  void _writeToBuffer(String text) {
    _buffer.write(text);
    _updateTrailingNewlines(text);
  }

  /// Writes [text] followed by a newline to the main buffer and updates
  /// [_trailingNewlines].
  void _writelnToBuffer([String text = '']) {
    _buffer.writeln(text);
    if (text.isEmpty) {
      // writeln('') writes just '\n'.
      _trailingNewlines++;
    } else {
      // writeln(text) writes text + '\n', so exactly 1 trailing newline.
      _trailingNewlines = 1;
    }
  }

  /// Updates [_trailingNewlines] based on the characters at the end of [text].
  void _updateTrailingNewlines(String text) {
    if (text.isEmpty) return;
    // Count trailing '\n' characters from the end of text.
    var count = 0;
    for (var i = text.length - 1; i >= 0 && text.codeUnitAt(i) == 0x0A; i--) {
      count++;
    }
    if (count == text.length) {
      // The entire text is newlines — add to existing count.
      _trailingNewlines += count;
    } else {
      // Text contains non-newline characters, so reset and count from end.
      _trailingNewlines = count;
    }
  }

  /// Writes [text] to either the cell buffer (if inside a table cell) or
  /// the main buffer.
  void _writeToTarget(String text) {
    if (_cellBuffer != null) {
      _cellBuffer!.write(text);
    } else {
      _writeToBuffer(text);
    }
  }

  /// Ensures the buffer ends with a blank line (two newlines) for block
  /// element separation. Does nothing if the buffer is empty.
  void _ensureBlankLine() {
    if (_buffer.isEmpty) return;
    if (_trailingNewlines >= 2) return;
    if (_trailingNewlines == 1) {
      _writelnToBuffer();
    } else {
      _writelnToBuffer();
      _writelnToBuffer();
    }
  }

  /// Returns the tag of the parent element, or `null` if at the top level.
  String? _parentTag() {
    if (_elementStack.length < 2) return null;
    return _elementStack[_elementStack.length - 2].tag;
  }

  /// Returns `true` if we are currently inside a `blockquote` element.
  bool _isInsideBlockquote() {
    for (var i = _elementStack.length - 2; i >= 0; i--) {
      if (_elementStack[i].tag == 'blockquote') return true;
    }
    return false;
  }

  /// Returns `true` if we are currently inside a `li` element.
  bool _isInsideListItem() {
    for (var i = _elementStack.length - 2; i >= 0; i--) {
      if (_elementStack[i].tag == 'li') return true;
    }
    return false;
  }

  /// Returns `true` if [element] is not the first child of its parent.
  bool _isNotFirstChild(md.Element element) {
    if (_elementStack.length < 2) return false;
    final parent = _elementStack[_elementStack.length - 2];
    final children = parent.children;
    if (children == null || children.isEmpty) return false;
    return !identical(children.first, element);
  }

  /// Returns `true` if [element] is a `<pre>` containing exactly one
  /// `<code>` child element.
  bool _hasSingleCodeChild(md.Element element) {
    final children = element.children;
    if (children == null || children.length != 1) return false;
    final child = children.first;
    return child is md.Element && child.tag == 'code';
  }

  /// Computes the minimum fence delimiter (backticks) needed for a code block
  /// whose content may itself contain backtick fences.
  ///
  /// Scans the content for runs of consecutive backticks and returns a fence
  /// that is at least one backtick longer than the longest run found, with a
  /// minimum of 3 (the CommonMark standard).
  String _computeFence(md.Element codeElement) {
    final content = codeElement.textContent;
    var maxRun = 0;
    var currentRun = 0;
    for (var i = 0; i < content.length; i++) {
      if (content[i] == '`') {
        currentRun++;
        if (currentRun > maxRun) maxRun = currentRun;
      } else {
        currentRun = 0;
      }
    }
    final needed = maxRun >= 3 ? maxRun + 1 : 3;
    return '`' * needed;
  }

  /// Extracts the language identifier from a fenced code block's `<code>`
  /// element, typically stored in the `class` attribute as `language-<name>`.
  String _extractLanguage(md.Element codeElement) {
    final className = codeElement.attributes['class'] ?? '';
    if (className.startsWith('language-')) {
      return className.substring('language-'.length);
    }
    // Default to 'dart' for Dart API documentation code blocks.
    return 'dart';
  }

  /// Renders the text content of a fenced code block's `<code>` element.
  ///
  /// Code block content is rendered verbatim (no escaping). When [indent] is
  /// provided (non-empty), each line of the code block is prefixed with it,
  /// which is necessary for code blocks inside list items.
  void _renderCodeBlockContent(md.Element codeElement, {String indent = ''}) {
    final content = codeElement.textContent;
    // Remove trailing newline if present (the closing ``` will add its own).
    final trimmed = content.endsWith('\n')
        ? content.substring(0, content.length - 1)
        : content;
    if (indent.isNotEmpty) {
      final lines = trimmed.split('\n');
      _writeToBuffer(lines.map((line) => '$indent$line').join('\n'));
    } else {
      _writeToBuffer(trimmed);
    }
  }

  /// Constructs an HTML opening tag string for unknown/pass-through elements.
  String _openTag(md.Element element) {
    final sb = StringBuffer('<${element.tag}');
    for (final entry in element.attributes.entries) {
      final escaped = entry.value
          .replaceAll('&', '&amp;')
          .replaceAll('"', '&quot;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      sb.write(' ${entry.key}="$escaped"');
    }
    if (element.isEmpty) {
      sb.write(' />');
    } else {
      sb.write('>');
    }
    return sb.toString();
  }

  /// Constructs an HTML entity-escaped opening tag for unsafe elements.
  ///
  /// Produces `&lt;tag attrs&gt;` instead of `<tag attrs>` so Vue's
  /// template compiler treats it as text, not an HTML element.
  String _escapedOpenTag(md.Element element) {
    final sb = StringBuffer('&lt;${element.tag}');
    for (final entry in element.attributes.entries) {
      sb.write(' ${entry.key}="${entry.value}"');
    }
    if (element.isEmpty) {
      sb.write(' /&gt;');
    } else {
      sb.write('&gt;');
    }
    return sb.toString();
  }

  /// Renders the collected table data as a markdown table.
  void _renderTable() {
    if (_tableRows.isEmpty) return;

    final headerRow = _tableRows.first;
    final columnCount = headerRow.length;

    String escapeCell(String s) => s.replaceAll('|', r'\|');

    // Render header row.
    _writeToBuffer('| ');
    _writeToBuffer(headerRow.map(escapeCell).join(' | '));
    _writelnToBuffer(' |');

    // Render separator row with alignment.
    _writeToBuffer('|');
    for (var i = 0; i < columnCount; i++) {
      final alignment = i < _tableAlignments.length
          ? _tableAlignments[i]
          : null;
      if (alignment != null && alignment.contains('text-align: center')) {
        _writeToBuffer(':---:|');
      } else if (alignment != null && alignment.contains('text-align: right')) {
        _writeToBuffer('---:|');
      } else if (alignment != null && alignment.contains('text-align: left')) {
        _writeToBuffer(':---|');
      } else {
        _writeToBuffer('---|');
      }
    }
    _writelnToBuffer();

    // Render body rows (skip header row).
    for (var r = 1; r < _tableRows.length; r++) {
      final row = _tableRows[r];
      _writeToBuffer('| ');
      // Pad row to match column count if needed.
      final paddedRow = List<String>.generate(
        columnCount,
        (i) => i < row.length ? row[i] : '',
      );
      _writeToBuffer(paddedRow.map(escapeCell).join(' | '));
      _writelnToBuffer(' |');
    }
  }
}
