// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:path/path.dart' as p;

/// Marker used to identify generated legacy guide redirect files.
const legacyGuideRedirectMarker =
    '<!-- dartdoc_modern:legacy-guide-redirect -->';

/// Redirect metadata for a legacy `guide/*.html` path.
class LegacyGuideRedirect {
  final String outputPath;
  final String redirectTarget;

  const LegacyGuideRedirect({
    required this.outputPath,
    required this.redirectTarget,
  });
}

/// Builds redirect metadata for a generated guide markdown file.
///
/// For example:
/// - `guide/getting-started.md` -> `guide/getting-started.html` -> `getting-started`
/// - `guide/advanced/index.md` -> `guide/advanced/index.html` -> `./`
LegacyGuideRedirect? legacyGuideRedirectFor(String guideRelativePath) {
  if (!guideRelativePath.startsWith('guide/') ||
      !guideRelativePath.endsWith('.md')) {
    return null;
  }

  if (guideRelativePath == 'guide/index.md') {
    return null;
  }

  final baseName = p.posix.basenameWithoutExtension(guideRelativePath);
  final redirectTarget = baseName == 'index' ? './' : baseName;

  return LegacyGuideRedirect(
    outputPath: p.posix.setExtension(guideRelativePath, '.html'),
    redirectTarget: redirectTarget,
  );
}

/// Returns `true` when the file content looks like our generated redirect.
bool isLegacyGuideRedirectHtml(String content) {
  return content.contains(legacyGuideRedirectMarker);
}

/// Renders a small static HTML redirect for old guide URLs.
String renderLegacyGuideRedirectHtml(String redirectTarget) {
  final escapedTarget = _escapeHtml(redirectTarget);
  final scriptTarget = jsonEncode(redirectTarget);

  return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Guide Redirect</title>
    $legacyGuideRedirectMarker
    <meta name="robots" content="noindex">
    <link rel="canonical" href="$escapedTarget">
    <meta http-equiv="refresh" content="0; url=$escapedTarget">
    <script>
      window.location.replace($scriptTarget);
    </script>
  </head>
  <body>
    <p>Redirecting to <a href="$escapedTarget">$escapedTarget</a>...</p>
  </body>
</html>
''';
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
