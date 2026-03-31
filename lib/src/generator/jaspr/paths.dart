// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartdoc_vitepress/src/generator/core/path_utils.dart'
    as path_utils;
import 'package:dartdoc_vitepress/src/generator/vitepress/paths.dart';
import 'package:dartdoc_vitepress/src/model/model.dart';

export 'package:dartdoc_vitepress/src/generator/vitepress/paths.dart'
    show
        VitePressPathResolver,
        isDuplicateSdkLibrary,
        isInternalSdkLibrary;

/// Jaspr uses the same public URL structure as VitePress, but stores markdown
/// source files under `content/`.
class JasprPathResolver extends VitePressPathResolver {
  @override
  String? filePathFor(Documentable element) {
    final path = super.filePathFor(element);
    if (path == null || path.startsWith('content/')) {
      return path;
    }
    return 'content/$path';
  }

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
