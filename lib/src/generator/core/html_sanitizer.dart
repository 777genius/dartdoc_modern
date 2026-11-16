// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Format-agnostic HTML sanitization for documentation content.
///
/// Removes dangerous HTML elements (script, style, iframe, etc.) while
/// preserving safe content. Shared across all output format backends.
/// Must not contain any format-specific escaping (e.g. Vue template syntax).
library;

import 'package:dartdoc_modern/src/logging.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

// ---------------------------------------------------------------------------
// Pre-compiled patterns for sanitization.
// ---------------------------------------------------------------------------
final _scriptOpenClose = RegExp(
  r'<\s*script\b[^>]*>[\s\S]*?<\s*/\s*script\s*>',
  caseSensitive: false,
);
final _scriptSelfClose = RegExp(
  r'<\s*script\b[^>]*/\s*>',
  caseSensitive: false,
);
final _styleOpenClose = RegExp(
  r'<\s*style\b[^>]*>[\s\S]*?<\s*/\s*style\s*>',
  caseSensitive: false,
);
final _baseTag = RegExp(r'<\s*base\b[^>]*/?\s*>', caseSensitive: false);
final _metaTag = RegExp(r'<\s*meta\b[^>]*/?\s*>', caseSensitive: false);
final _linkTag = RegExp(r'<\s*link\b[^>]*/?\s*>', caseSensitive: false);
// Match complete iframe elements, respecting '>' within quoted attributes.
// Malformed / unclosed iframe opening tags are handled separately below.
final _iframeEndTag = RegExp(
  r'</\s*iframe\s*>',
  caseSensitive: false,
);
// Use the HTML tokenizer's attribute value states to find opening tags.
// An unquoted literal quote is NOT an opening quote.
const _forbiddenElementNames = {
  'script',
  'style',
  'embed',
  'object',
  'applet',
  'form',
  'svg',
};
final _urlScheme = RegExp(r'^([a-z][a-z0-9+.-]*):');
final _urlControlChars = RegExp(r'[\u0000-\u0020\u007f]');
final _dangerousEmbedOpenClose = {
  for (final tag in ['embed', 'object', 'applet', 'form', 'svg'])
    tag: RegExp(
      '<\\s*$tag\\b[^>]*>[\\s\\S]*?<\\s*/\\s*$tag\\s*>',
      caseSensitive: false,
    ),
};
final _dangerousEmbedSelfClose = {
  for (final tag in ['embed', 'object', 'applet', 'form', 'svg'])
    tag: RegExp('<\\s*$tag\\b[^>]*/\\s*>', caseSensitive: false),
};

/// Built-in iframe hosts that are always allowed.
const builtinAllowedHosts = {
  'youtube.com',
  'www.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
  'dartpad.dev',
  'www.dartpad.dev',
  'dartpad.cn',
  'www.dartpad.cn',
};

const _maxSanitizerLogsPerKind = 5;
final _sanitizerLogCounts = <String, int>{};

/// Sanitizes HTML by removing dangerous elements and attributes.
///
/// Removes:
/// - `<script>`, `<style>`, `<base>`, `<meta>`, `<link>` tags
/// - `<embed>`, `<object>`, `<applet>`, `<form>`, `<svg>` tags
/// - `<iframe>` tags whose host is not in the allowed set
/// - `javascript:` and `data:` URLs
/// - `srcdoc` iframe attributes (inline executable HTML)
/// - Inline event handlers (`on*=`)
///
/// Does NOT perform format-specific escaping (e.g. Vue template syntax).
/// Format backends should apply their own escaping after calling this.
String sanitizeHtml(String html, {Set<String> extraAllowedHosts = const {}}) {
  html = html.replaceAll('\x00', '');

  // Removing a nested tag can expose another forbidden opener.
  String previous;
  do {
    previous = html;
    html = _removeForbiddenElements(html, extraAllowedHosts);
  } while (html != previous);

  return _sanitizeHtmlAttributes(html);
}

String _removeForbiddenElements(String html, Set<String> extraAllowedHosts) {
  html = _warnOnRemoval(html, _scriptOpenClose, '<script>');
  html = _warnOnRemoval(html, _scriptSelfClose, '<script/>');
  html = _warnOnRemoval(html, _styleOpenClose, '<style>');
  for (final tag in ['embed', 'object', 'applet', 'form', 'svg']) {
    html = _warnOnRemoval(html, _dangerousEmbedOpenClose[tag]!, '<$tag>');
    html = _warnOnRemoval(html, _dangerousEmbedSelfClose[tag]!, '<$tag/>');
  }

  html = _warnOnRemoval(html, _baseTag, '<base>');
  html = _warnOnRemoval(html, _metaTag, '<meta>');
  html = _warnOnRemoval(html, _linkTag, '<link>');
  html = _removeDisallowedIframes(html, extraAllowedHosts);

  // Void <embed> and incomplete forbidden elements may lack a closing tag.
  return _rewriteOpeningTags(html, (tag, original) {
    if (_forbiddenElementNames.contains(tag.name)) {
      _logSanitizerWarning(
        'removed dangerous HTML opener',
        'sanitizeHtml: removed <${tag.name}> opening tag',
      );
      return '';
    }
    return original;
  });
}

String _removeDisallowedIframes(String html, Set<String> extraAllowedHosts) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final tag in _scanOpeningTags(html)) {
    if (tag.name != 'iframe' || tag.start < cursor) continue;
    buffer.write(html.substring(cursor, tag.start));

    if (!tag.complete) {
      buffer.write('&lt;');
      cursor = tag.end;
      continue;
    }

    final original = html.substring(tag.start, tag.end);
    final src = _parseOpeningTag(original)?.attributes['src'];
    final uri = src == null ? null : Uri.tryParse(src);
    final allowed = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        (builtinAllowedHosts.contains(uri.host.toLowerCase()) ||
            extraAllowedHosts.contains(uri.host.toLowerCase()));
    final closing = _iframeEndTag.firstMatch(html, tag.end);
    if (allowed && closing != null) {
      buffer.write(html.substring(tag.start, closing.end));
    } else {
      _logSanitizerWarning(
        'removed disallowed iframe',
        'sanitizeHtml: removed iframe with untrusted or missing src',
      );
    }
    cursor = closing?.end ?? tag.end;
  }
  buffer.write(html.substring(cursor));
  return buffer.toString();
}

/// A scanned opening tag. Incomplete tags include just their '<' character.
final class _OpeningTagSpan {
  const _OpeningTagSpan(this.start, this.end, this.name, this.complete);

  final int start;
  final int end;
  final String name;
  final bool complete;
}

enum _TagScanState {
  between,
  attributeName,
  beforeValue,
  unquoted,
  singleQuoted,
  doubleQuoted,
}

/// Find tag boundaries without regex backtracking. Quotes only start an
/// attribute value after '='. A quote within an unquoted value is literal.
List<_OpeningTagSpan> _scanOpeningTags(String html) {
  final tags = <_OpeningTagSpan>[];
  var position = 0;

  while (position < html.length) {
    final start = html.indexOf('<', position);
    if (start < 0 || start + 1 >= html.length) break;
    if (!_isAsciiLetter(html.codeUnitAt(start + 1))) {
      position = start + 1;
      continue;
    }

    var index = start + 2;
    while (index < html.length && _isTagNameChar(html.codeUnitAt(index))) {
      index++;
    }
    final name = html.substring(start + 1, index).toLowerCase();
    var state = _TagScanState.between;
    var complete = false;

    while (index < html.length) {
      final unit = html.codeUnitAt(index);
      if (state == _TagScanState.singleQuoted) {
        if (unit == 39) state = _TagScanState.between;
      } else if (state == _TagScanState.doubleQuoted) {
        if (unit == 34) state = _TagScanState.between;
      } else if (unit == 62) {
        complete = true;
        index++;
        break;
      } else if (state == _TagScanState.between) {
        if (!_isHtmlSpace(unit) && unit != 47) {
          state = _TagScanState.attributeName;
        }
      } else if (state == _TagScanState.attributeName) {
        if (unit == 60) {
          // A new '<' in an unquoted name is malformed; escape the outer
          // opener and inspect the nested tag separately on the next scan.
          break;
        }
        if (unit == 61) {
          state = _TagScanState.beforeValue;
        } else if (_isHtmlSpace(unit) || unit == 47) {
          state = _TagScanState.between;
        }
      } else if (state == _TagScanState.beforeValue) {
        if (unit == 34) {
          state = _TagScanState.doubleQuoted;
        } else if (unit == 39) {
          state = _TagScanState.singleQuoted;
        } else if (!_isHtmlSpace(unit)) {
          state = _TagScanState.unquoted;
        }
      } else if (state == _TagScanState.unquoted && _isHtmlSpace(unit)) {
        state = _TagScanState.between;
      }
      index++;
    }

    if (complete) {
      tags.add(_OpeningTagSpan(start, index, name, true));
      position = index;
    } else {
      tags.add(_OpeningTagSpan(start, start + 1, name, false));
      position = start + 1;
    }
  }
  return tags;
}

bool _isAsciiLetter(int code) =>
    (code >= 65 && code <= 90) || (code >= 97 && code <= 122);

bool _isTagNameChar(int code) =>
    _isAsciiLetter(code) ||
    (code >= 48 && code <= 57) ||
    code == 45 ||
    code == 58;

bool _isHtmlSpace(int code) =>
    code == 32 || code == 9 || code == 10 || code == 13 || code == 12;

String _rewriteOpeningTags(
  String html,
  String Function(_OpeningTagSpan, String) rewrite,
) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final tag in _scanOpeningTags(html)) {
    buffer.write(html.substring(cursor, tag.start));
    buffer.write(
      tag.complete
          ? rewrite(tag, html.substring(tag.start, tag.end))
          : '&lt;',
    );
    cursor = tag.end;
  }
  buffer.write(html.substring(cursor));
  return buffer.toString();
}

/// Validate URL and event attributes using the browser's tag boundaries.
String _sanitizeHtmlAttributes(String html) {
  return _rewriteOpeningTags(html, (tag, originalTag) {
    final element = _parseOpeningTag(originalTag);
    if (element == null) {
      // The fragment parser ignores table-context tags such as td and tr.
      // Strip their unchecked attributes instead of returning raw HTML.
      return '<${tag.name}${originalTag.endsWith('/>') ? '/>' : '>'}';
    }

    var removed = false;
    final attrs = <MapEntry<String, String>>[];
    for (final attribute in element.attributes.entries) {
      final name = attribute.key.toString().toLowerCase();
      final value = attribute.value;
      final forbidden = name == 'srcdoc' ||
          name.startsWith('on') ||
          ((name == 'href' || name == 'src') && !_isSafeUrl(name, value));
      if (forbidden) {
        removed = true;
        _logSanitizerWarning(
          'removed unsafe HTML attribute',
          'sanitizeHtml: removed unsafe $name attribute',
        );
      } else {
        attrs.add(MapEntry(name, value));
      }
    }
    if (!removed) return originalTag;

    final encodedAttributes = attrs
        .map((entry) =>
            ' ${entry.key}="${_escapeHtmlAttributeValue(entry.value)}"')
        .join();
    final terminator = originalTag.endsWith('/>') ? '/>' : '>';
    return '<${tag.name}$encodedAttributes$terminator';
  });
}

// Use the HTML5 attribute parser after identifying the tag's actual span.
dom.Element? _parseOpeningTag(String openingTag) {
  final fragment = parseFragment(openingTag);
  for (final node in fragment.nodes) {
    if (node is dom.Element) return node;
  }
  return null;
}

bool _isSafeUrl(String attribute, String value) {
  // HTML5 parsing decodes entities in attribute values before this check.
  final normalized = value.replaceAll(_urlControlChars, '').toLowerCase();
  final scheme = _urlScheme.firstMatch(normalized)?.group(1);
  if (scheme == null) return true; // Relative URL or fragment.
  if (scheme == 'https' || scheme == 'http') return true;
  return attribute == 'href' && (scheme == 'mailto' || scheme == 'tel');
}

String _escapeHtmlAttributeValue(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;');

/// Removes all matches of [pattern] from [html], logging a warning
/// for each occurrence with the given [description].
String _warnOnRemoval(String html, Pattern pattern, String description) {
  return html.replaceAllMapped(pattern, (match) {
    _logSanitizerWarning(
      'removed $description tag',
      'sanitizeHtml: removed $description tag',
    );
    return '';
  });
}

void _logSanitizerWarning(String key, String message) {
  final count = (_sanitizerLogCounts[key] ?? 0) + 1;
  _sanitizerLogCounts[key] = count;

  if (count <= _maxSanitizerLogsPerKind) {
    logWarning(message);
    if (count == _maxSanitizerLogsPerKind) {
      logWarning(
        'sanitizeHtml: suppressing further "$key" warnings after '
        '$_maxSanitizerLogsPerKind occurrences',
      );
    }
  }
}
