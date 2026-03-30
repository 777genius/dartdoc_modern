// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Format-agnostic HTML sanitization for documentation content.
///
/// Removes dangerous HTML elements (script, style, iframe, etc.) while
/// preserving safe content. Shared across all output format backends.
/// Must not contain any format-specific escaping (e.g. Vue template syntax).
library;

import 'package:dartdoc_vitepress/src/logging.dart';

// ---------------------------------------------------------------------------
// Pre-compiled patterns for sanitization.
// ---------------------------------------------------------------------------
final _scriptOpenClose = RegExp(
    r'<\s*script\b[^>]*>[\s\S]*?<\s*/\s*script\s*>',
    caseSensitive: false);
final _scriptSelfClose =
    RegExp(r'<\s*script\b[^>]*/\s*>', caseSensitive: false);
final _styleOpenClose = RegExp(
    r'<\s*style\b[^>]*>[\s\S]*?<\s*/\s*style\s*>',
    caseSensitive: false);
final _baseTag = RegExp(r'<\s*base\b[^>]*/?\s*>', caseSensitive: false);
final _metaTag = RegExp(r'<\s*meta\b[^>]*/?\s*>', caseSensitive: false);
final _linkTag = RegExp(r'<\s*link\b[^>]*/?\s*>', caseSensitive: false);
final _iframeTag = RegExp(
    r'<\s*iframe\b[^>]*>[\s\S]*?<\s*/\s*iframe\s*>',
    caseSensitive: false);
final _iframeSrcAttr =
    RegExp(r"""src\s*=\s*["']([^"']*)["']""", caseSensitive: false);
final _javascriptUrl =
    RegExp(r'''(href|src)\s*=\s*["']?\s*javascript:''', caseSensitive: false);
final _dataUrl =
    RegExp(r'''(href|src)\s*=\s*["']?\s*data:''', caseSensitive: false);
final _eventHandler = RegExp(
    r'''\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false);
final _dangerousEmbedOpenClose = {
  for (final tag in ['embed', 'object', 'applet', 'form', 'svg'])
    tag: RegExp('<\\s*$tag\\b[^>]*>[\\s\\S]*?<\\s*/\\s*$tag\\s*>',
        caseSensitive: false),
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

/// Sanitizes HTML by removing dangerous elements and attributes.
///
/// Removes:
/// - `<script>`, `<style>`, `<base>`, `<meta>`, `<link>` tags
/// - `<embed>`, `<object>`, `<applet>`, `<form>`, `<svg>` tags
/// - `<iframe>` tags whose host is not in the allowed set
/// - `javascript:` and `data:` URLs
/// - Inline event handlers (`on*=`)
///
/// Does NOT perform format-specific escaping (e.g. Vue template syntax).
/// Format backends should apply their own escaping after calling this.
String sanitizeHtml(String html,
    {Set<String> extraAllowedHosts = const {}}) {
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
  html = html.replaceAllMapped(
    _iframeTag,
    (match) {
      final tag = match.group(0)!;
      final srcMatch = _iframeSrcAttr.firstMatch(tag);
      if (srcMatch != null) {
        final src = srcMatch.group(1)!;
        final uri = Uri.tryParse(src);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          final host = uri.host.toLowerCase();
          if (builtinAllowedHosts.contains(host) ||
              extraAllowedHosts.contains(host)) {
            return tag; // Keep allowed iframe embeds.
          }
          logWarning('sanitizeHtml: removed <iframe> with host "$host". '
              'To allow it, add "$host" to the allowedIframeHosts option '
              'in dartdoc_options.yaml.');
        } else {
          logWarning(
              'sanitizeHtml: removed <iframe> with disallowed src: $src');
        }
      } else {
        logWarning('sanitizeHtml: removed <iframe> without src attribute');
      }
      return '';
    },
  );

  // 6. Remove javascript: URLs.
  html = html.replaceAllMapped(
    _javascriptUrl,
    (match) {
      logWarning('sanitizeHtml: removed javascript: URL');
      return '${match[1]}="';
    },
  );

  // 6b. Remove data: URIs in href/src.
  html = html.replaceAllMapped(
    _dataUrl,
    (match) {
      logWarning('sanitizeHtml: removed data: URI');
      return '${match[1]}="';
    },
  );

  // 7. Remove inline event handlers.
  html = _warnOnRemoval(html, _eventHandler, 'inline event handler');

  return html;
}

/// Removes all matches of [pattern] from [html], logging a warning
/// for each occurrence with the given [description].
String _warnOnRemoval(String html, Pattern pattern, String description) {
  return html.replaceAllMapped(
    pattern,
    (match) {
      logWarning('sanitizeHtml: removed $description tag');
      return '';
    },
  );
}
