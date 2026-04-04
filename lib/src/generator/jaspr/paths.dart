// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartdoc_vitepress/src/generator/core/path_utils.dart'
    as path_utils;
import 'package:dartdoc_vitepress/src/generator/vitepress/paths.dart';
import 'package:dartdoc_vitepress/src/model/model.dart';

export 'package:dartdoc_vitepress/src/generator/vitepress/paths.dart'
    show VitePressPathResolver, isDuplicateSdkLibrary, isInternalSdkLibrary;

/// Jaspr uses the same public URL structure as VitePress, but stores markdown
/// source files under `content/`.
class JasprPathResolver extends VitePressPathResolver {
  @override
  String? filePathFor(Documentable element) {
    if (element is Library) {
      if (isInternalSdkLibrary(element)) return null;
      return 'content/api/${dirNameFor(element)}/library.md';
    }

    final path = super.filePathFor(element);
    if (path == null || path.startsWith('content/')) {
      return path;
    }
    return 'content/$path';
  }

  @override
  String? urlFor(Documentable element) {
    if (element is Library) {
      if (isInternalSdkLibrary(element)) return null;
      return '/api/${dirNameFor(element)}/library';
    }
    return super.urlFor(element);
  }

  @override
  String? relativeUrlFor(Documentable element) => urlFor(element);

  static String sanitizeFileName(String name) {
    return path_utils.sanitizeFileName(name);
  }

  static String stripGenerics(String name) {
    return path_utils.stripGenerics(name);
  }

  static String sanitizeAnchor(String value) {
    return path_utils.sanitizeAnchor(value);
  }
}
