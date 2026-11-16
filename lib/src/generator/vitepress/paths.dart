// Backwards-compatible VitePress naming for the shared Markdown path resolver.
import 'package:dartdoc_modern/src/generator/core/markdown_paths.dart';
import 'package:dartdoc_modern/src/generator/core/path_utils.dart' as path_utils;

export 'package:dartdoc_modern/src/generator/core/path_utils.dart'
    show isDuplicateSdkLibrary, isInternalSdkLibrary;

class VitePressPathResolver extends MarkdownPathResolver {
  static String sanitizeFileName(String name) =>
      path_utils.sanitizeFileName(name);

  static String stripGenerics(String name) =>
      path_utils.stripGenerics(name);

  static String sanitizeAnchor(String value) =>
      MarkdownPathResolver.sanitizeAnchor(value);
}
