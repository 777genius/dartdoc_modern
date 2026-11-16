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
final _iframeTag = RegExp(
  r'''<\s*iframe\b(?:"[^"]*"|'[^']*'|[^'">])*?>[\s\S]*?<\s*/\s*iframe\s*>''',
  caseSensitive: false,
);
final _iframeOpeningTag = RegExp(
  r'''<\s*iframe\b(?:"[^"]*"|'[^']*'|[^'">])*?>''',
  caseSensitive: false,
);
// Match complete opening tags, including quoted '>' characters. Attribute
// names and values are validated by the HTML5 parser, not a whitespace regex.
final _openingTag = RegExp(
  r'''<([A-Za-z][A-Za-z0-9:-]*)(?:"[^"]*"|'[^']*'|[^'">])*?>''',
);
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
  // 1. Remove null bytes (bypass prevention).
  html = html.replaceAll('\x00', '');

  // 2. Remove <script> tags.
  html = _warnOnRemoval(html, _scriptOpenClose, '<script>');
  html = _warnOnRemoval(html, _scriptSelfClose, '<script/>');

  // 3. Remove <style> tags.
  html = _warnOnRemoval(html, _styleOpenClose, '<style>');

  // 4. Remove dangerous embed elements.
  for (final tag in ['embed', 'object', 'applet', 'form', 'svg']) {
    html = _warnOnRemoval(html, _dangerousEmbedOpenClose[tag]!, '<$tag>');
    html = _warnOnRemoval(html, _dangerousEmbedSelfClose[tag]!, '<$tag/>');
  }

  // 4b. Remove <base> tags.
  html = _warnOnRemoval(html, _baseTag, '<base>');

  // 4c. Remove <meta> tags.
  html = _warnOnRemoval(html, _metaTag, '<meta>');

  // 4d. Remove <link> tags.
  html = _warnOnRemoval(html, _linkTag, '<link>');

  // 5. Remove <iframe> tags whose host is not in the allowed set.
  html = html.replaceAllMapped(_iframeTag, (match) {
    final tag = match.group(0)!;
    final openingTag = _openingTag.firstMatch(tag)?.group(0);
    final src = openingTag == null
        ? null
        : _parseOpeningTag(openingTag)?.attributes['src'];
    if (src != null) {
      final uri = Uri.tryParse(src);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        final host = uri.host.toLowerCase();
        if (builtinAllowedHosts.contains(host) ||
            extraAllowedHosts.contains(host)) {
          return tag; // Keep allowed iframe embeds.
        }
        _logSanitizerWarning(
          'removed <iframe> with host "$host"',
          'sanitizeHtml: removed <iframe> with host "$host". '
              'To allow it, add "$host" to the allowedIframeHosts option '
              'in dartdoc_options.yaml.',
        );
      } else {
        _logSanitizerWarning(
          'removed <iframe> with disallowed src',
          'sanitizeHtml: removed <iframe> with disallowed src: $src',
        );
      }
    } else {
      _logSanitizerWarning(
        'removed <iframe> without src attribute',
        'sanitizeHtml: removed <iframe> without src attribute',
      );
    }
    return '';
  });

  // Reject unmatched iframe openers as well. HTML treats <iframe/> as a
  // non-void start tag, so a missing closing tag must not bypass the
  // trusted-host check. Keep opening tags of complete, allowed embeds.
  final completeIframes = _iframeTag.allMatches(html).toList();
  html = html.replaceAllMapped(_iframeOpeningTag, (match) {
    final covered = completeIframes.any(
      (iframe) => iframe.start <= match.start && match.end <= iframe.end,
    );
    if (covered) return match.group(0)!;
    _logSanitizerWarning(
      'removed unclosed <iframe>',
      'sanitizeHtml: removed unclosed or malformed <iframe> tag',
    );
    return '';
  });

  // Parse opening tags as HTML5: browsers recognize attributes after a
  // solidus or directly after a quoted value, without intervening whitespace.
  // Preserve the original spelling of tags that need no changes.
  html = _sanitizeHtmlAttributes(html);

  return html;
}

/// Removes dangerous attributes based on the browser's attribute tokenizer.
String _sanitizeHtmlAttributes(String html) {
  return html.replaceAllMapped(_openingTag, (match) {
    final originalTag = match.group(0)!;
    final element = _parseOpeningTag(originalTag);
    if (element == null) return originalTag;

    var removed = false;
    final attrs = <MapEntry<String, String>>[];
    for (final attribute in element.attributes.entries) {
      // The HTML DOM exposes attribute keys as Object (including namespaced
      // names), so normalize the name before validating and rebuilding them.
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
    return '<${match.group(1)}$encodedAttributes$terminator';
  });
}

// Use the browser's HTML5 attribute parser for whitelist and URL checks.
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
