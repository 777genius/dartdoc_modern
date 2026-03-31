// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartdoc_vitepress/src/generator/core/path_utils.dart'
    as path_utils;
import 'package:dartdoc_vitepress/src/generator/vitepress/docs.dart';

export 'package:dartdoc_vitepress/src/generator/vitepress/docs.dart'
    show MarkdownRenderer;

/// Jaspr shares the same documentation parsing pipeline as VitePress.
///
/// The output diverges later, inside the Jaspr backend, where VitePress-only
/// frontmatter and component syntax are stripped from generated markdown.
class JasprDocProcessor extends VitePressDocProcessor {
  JasprDocProcessor(
    super.packageGraph,
    super.paths, {
    super.allowedIframeHosts = const {},
  });

  static String sanitizeHtml(
    String html, {
    Set<String> extraAllowedHosts = const {},
  }) {
    return VitePressDocProcessor.sanitizeHtml(
      html,
      extraAllowedHosts: extraAllowedHosts,
    );
  }

  static String normalizeSdkLibraryPath(String path) {
    return path_utils.normalizeSdkLibraryPath(path);
  }
}
